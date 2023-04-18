use std::collections::{HashMap, HashSet};

use super::elixir_structs::*;

pub struct SceneValidator<'a> {
    objects: &'a [(ObjectName, Object)],
    final_object_name: &'a ObjectName,
}

impl<'a> SceneValidator<'a> {
    pub fn new(scene: &'a Scene) -> Self {
        Self {
            objects: &scene.objects,
            final_object_name: &scene.output,
        }
    }

    fn objects_map(&self) -> HashMap<&ObjectName, &Object> {
        self.objects
            .iter()
            .map(|(name, object)| (name, object))
            .collect::<HashMap<_, _>>()
    }

    fn check_for_duplicate_pad_refs(&self) -> Result<(), SceneParsingError> {
        let mut input_pads = HashSet::new();

        for (_, object) in self.objects {
            if let Object::Video(InputVideo { input_pad }) = object {
                if !input_pads.insert(input_pad) {
                    return Err(SceneParsingError::DuplicatePadReferences(input_pad.clone()));
                }
            }
        }

        Ok(())
    }

    fn check_for_duplicate_or_undefined_names(&self) -> Result<(), SceneParsingError> {
        if self.objects.is_empty() {
            return Err(SceneParsingError::UndefinedName(
                self.final_object_name.clone(),
            ));
        }

        let mut names = HashSet::new();
        for (name, _) in self.objects {
            if !names.insert(name) {
                return Err(SceneParsingError::DuplicateNames(name.clone()));
            }
        }

        for (_, object) in self.objects {
            for name in object.mentioned_names() {
                if !names.contains(name) {
                    return Err(SceneParsingError::UndefinedName(name.clone()));
                }
            }
        }

        Ok(())
    }

    fn check_for_unused_objects(&self) -> Result<(), SceneParsingError> {
        let defined_names = self
            .objects
            .iter()
            .map(|(name, _)| name)
            .collect::<HashSet<_>>();

        let mut used_names = self
            .objects
            .iter()
            .flat_map(|(_, object)| object.mentioned_names())
            .collect::<HashSet<_>>();

        if used_names.contains(self.final_object_name) {
            return Err(SceneParsingError::CycleDetected);
        } else {
            used_names.insert(self.final_object_name);
        }

        let unused_names = defined_names.difference(&used_names).collect::<Vec<_>>();

        if !unused_names.is_empty() {
            return Err(SceneParsingError::UnusedObject((*unused_names[0]).clone()));
        }

        Ok(())
    }

    /// returns `Err(SceneParsingError::CycleDetected)` if a cycle exists in the scene graph, `Ok(())` otherwise.
    fn contains_cycle(&self) -> Result<(), SceneParsingError> {
        enum NodeState {
            BeingVisited,
            Visited,
        }

        fn visit(
            name: &ObjectName,
            objects: &HashMap<&ObjectName, &Object>,
            visited: &mut HashMap<ObjectName, NodeState>,
        ) -> Result<(), SceneParsingError> {
            match visited.get(name) {
                Some(NodeState::BeingVisited) => return Err(SceneParsingError::CycleDetected),
                Some(NodeState::Visited) => return Ok(()),
                _ => {}
            }

            visited.insert(name.clone(), NodeState::BeingVisited);

            for child in objects[name].previous_names() {
                visit(child, objects, visited)?;
            }

            visited.insert(name.clone(), NodeState::Visited);

            Ok(())
        }

        let mut visited = HashMap::new();

        visit(self.final_object_name, &self.objects_map(), &mut visited)
    }

    pub fn validate(&self) -> Result<(), SceneParsingError> {
        self.check_for_duplicate_pad_refs()?;

        self.check_for_duplicate_or_undefined_names()?;

        self.check_for_unused_objects()?;

        self.contains_cycle()?;

        Ok(())
    }
}

#[derive(Debug, thiserror::Error)]
pub enum SceneParsingError {
    #[error("cycle detected in the scene graph")]
    CycleDetected,

    #[error("the scene graph contains an object name that is not defined anywhere: {0:?}")]
    UndefinedName(ObjectName),

    #[error("object name {0:?} is defined multiple times in the scene graph")]
    DuplicateNames(ObjectName),

    #[error("the scene graph contains two InputVideos referencing the same Membrane.Pad: {0}")]
    DuplicatePadReferences(PadRef),

    #[error("the scene graph contains an object which is not used in compositing: {0:?}")]
    UnusedObject(ObjectName),
}

impl rustler::Encoder for SceneParsingError {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        match self {
            SceneParsingError::CycleDetected => rustler::Atom::from_str(env, "cycle_detected")
                .unwrap()
                .encode(env),

            SceneParsingError::UndefinedName(name) => (
                rustler::Atom::from_str(env, "undefined_name").unwrap(),
                name,
            )
                .encode(env),

            SceneParsingError::DuplicateNames(name) => (
                rustler::Atom::from_str(env, "duplicate_names").unwrap(),
                name,
            )
                .encode(env),

            SceneParsingError::DuplicatePadReferences(pad) => (
                rustler::Atom::from_str(env, "duplicate_pad_refs").unwrap(),
                pad,
            )
                .encode(env),

            SceneParsingError::UnusedObject(name) => {
                (rustler::Atom::from_str(env, "unused_name").unwrap(), name).encode(env)
            }
        }
    }
}

impl From<SceneParsingError> for rustler::Error {
    fn from(err: SceneParsingError) -> Self {
        Self::Term(Box::new(err))
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn scene_parsing_finds_cycle() {
        let a = Name::Atom("a".into());
        let b = Name::Atom("b".into());
        let c = Name::Atom("c".into());

        let scene = Scene {
            objects: vec![
                (
                    a.clone(),
                    Object::Texture(Texture {
                        input: b.clone(),
                        transformations: vec![],
                        resolution: TextureOutputResolution::TransformedInputResolution,
                    }),
                ),
                (
                    b,
                    Object::Texture(Texture {
                        input: c.clone(),
                        transformations: vec![],
                        resolution: TextureOutputResolution::TransformedInputResolution,
                    }),
                ),
                (
                    c.clone(),
                    Object::Texture(Texture {
                        input: a,
                        transformations: vec![],
                        resolution: TextureOutputResolution::TransformedInputResolution,
                    }),
                ),
            ],
            output: c,
        };

        let result: Result<crate::scene::Scene, _> = scene.try_into();

        assert!(matches!(result, Err(SceneParsingError::CycleDetected)))
    }

    #[test]
    fn scene_parsing_detects_undefined_name() {
        let a = Name::Atom("a".into());
        let b = Name::Atom("b".into());
        let c = Name::Atom("c".into());

        let scene = Scene {
            objects: vec![
                (
                    a,
                    Object::Texture(Texture {
                        input: b.clone(),
                        transformations: vec![],
                        resolution: TextureOutputResolution::TransformedInputResolution,
                    }),
                ),
                (
                    b.clone(),
                    Object::Texture(Texture {
                        input: c.clone(),
                        transformations: vec![],
                        resolution: TextureOutputResolution::TransformedInputResolution,
                    }),
                ),
            ],
            output: b,
        };

        let result: Result<crate::scene::Scene, _> = scene.try_into();
        assert!(result.is_err());
        if let Err(SceneParsingError::UndefinedName(name)) = result {
            assert_eq!(name, c);
        } else {
            panic!("Parser failed to detect an undefined name")
        }
    }

    #[test]
    fn scene_parsing_detects_multiple_name_definitions() {
        let a = Name::Atom("a".into());
        let b = Name::Atom("b".into());

        let scene = Scene {
            objects: vec![
                (
                    a.clone(),
                    Object::Video(InputVideo {
                        input_pad: "pad".into(),
                    }),
                ),
                (
                    a.clone(),
                    Object::Texture(Texture {
                        input: a.clone(),
                        transformations: vec![],
                        resolution: TextureOutputResolution::TransformedInputResolution,
                    }),
                ),
                (
                    b.clone(),
                    Object::Texture(Texture {
                        input: a.clone(),
                        transformations: vec![],
                        resolution: TextureOutputResolution::TransformedInputResolution,
                    }),
                ),
            ],
            output: b,
        };

        let result: Result<crate::scene::Scene, _> = scene.try_into();
        assert!(result.is_err());
        if let Err(SceneParsingError::DuplicateNames(name)) = result {
            assert_eq!(name, a);
        } else {
            panic!("Parser failed to detect a name defined multiple times")
        }
    }

    #[test]
    fn scene_parsing_detects_duplicated_pad_refs() {
        let a = Name::Atom("a".into());
        let b = Name::Atom("b".into());
        let c = Name::Atom("c".into());

        let inputs = HashMap::from_iter(vec![(a.clone(), a.clone()), (b.clone(), b.clone())]);

        let scene = Scene {
            objects: vec![
                (
                    a.clone(),
                    Object::Video(InputVideo {
                        input_pad: "pad".into(),
                    }),
                ),
                (
                    b,
                    Object::Video(InputVideo {
                        input_pad: "pad".into(),
                    }),
                ),
                (
                    c.clone(),
                    Object::Layout(Layout {
                        inputs,
                        resolution: LayoutOutputResolution::Name(a),
                        implementation: 42,
                    }),
                ),
            ],
            output: c,
        };

        let result: Result<crate::scene::Scene, _> = scene.try_into();
        assert!(result.is_err());
        if let Err(SceneParsingError::DuplicatePadReferences(pad)) = result {
            assert_eq!(pad, "pad");
        } else {
            panic!("Parser failed to detect duplicate pad references")
        }
    }

    #[test]
    fn scene_parsing_detects_unused_objects() {
        let a = Name::Atom("a".into());
        let b = Name::Atom("b".into());
        let c = Name::Atom("c".into());
        let d = Name::Atom("d".into());

        let inputs = HashMap::from_iter(vec![(a.clone(), a.clone()), (b.clone(), b.clone())]);

        let scene = Scene {
            objects: vec![
                (
                    a.clone(),
                    Object::Video(InputVideo {
                        input_pad: "pad1".into(),
                    }),
                ),
                (
                    b,
                    Object::Video(InputVideo {
                        input_pad: "pad2".into(),
                    }),
                ),
                (
                    c.clone(),
                    Object::Layout(Layout {
                        inputs,
                        resolution: LayoutOutputResolution::Name(a),
                        implementation: 42,
                    }),
                ),
                (
                    d.clone(),
                    Object::Video(InputVideo {
                        input_pad: "pad3".into(),
                    }),
                ),
            ],
            output: c,
        };

        let result: Result<crate::scene::Scene, _> = scene.try_into();
        assert!(result.is_err());
        if let Err(SceneParsingError::UnusedObject(name)) = result {
            assert_eq!(name, d);
        } else {
            panic!("Parser failed to detect unused objects")
        }
    }
}
