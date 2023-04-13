use std::collections::{HashMap, HashSet};

use super::elixir_structs::*;

impl Object {
    fn mentioned_names(&self) -> Vec<&Name> {
        match self {
            Object::Layout(layout) => layout.mentioned_names(),
            Object::Texture(texture) => texture.mentioned_names(),
            Object::Video(_) => Vec::new(),
        }
    }
}

impl Texture {
    fn mentioned_names(&self) -> Vec<&Name> {
        let mut names = vec![&self.input];

        if let TextureOutputResolution::Name(name) = &self.resolution {
            names.push(name);
        }

        names
    }
}

impl Layout {
    fn mentioned_names(&self) -> Vec<&Name> {
        let mut names = self.inputs.values().collect::<Vec<_>>();

        if let LayoutOutputResolution::Name(name) = &self.resolution {
            names.push(name);
        }

        names
    }
}

impl Scene {
    fn check_for_duplicate_pad_refs(
        objects: &[(ObjectName, Object)],
    ) -> Result<(), SceneParsingError> {
        let mut set = HashSet::new();

        for (_, object) in objects {
            if let Object::Video(InputVideo { input_pad }) = object {
                if set.contains(input_pad) {
                    return Err(SceneParsingError::DuplicatePadReferences(input_pad.clone()));
                }

                set.insert(input_pad);
            }
        }

        Ok(())
    }

    fn check_for_duplicate_or_undefined_names(
        objects: &[(ObjectName, Object)],
        final_object_name: &ObjectName,
    ) -> Result<(), SceneParsingError> {
        if objects.is_empty() {
            return Err(SceneParsingError::UndefinedName(final_object_name.clone()));
        }

        let mut names = HashSet::new();
        for (name, _) in objects {
            if names.contains(name) {
                return Err(SceneParsingError::DuplicateNames(name.clone()));
            }

            names.insert(name);
        }

        for (_, object) in objects {
            for name in object.mentioned_names() {
                if !names.contains(name) {
                    return Err(SceneParsingError::UndefinedName(name.clone()));
                }
            }
        }

        Ok(())
    }

    fn check_for_unused_objects(
        objects: &[(ObjectName, Object)],
        final_object_name: &ObjectName,
    ) -> Result<(), SceneParsingError> {
        let defined_names = objects.iter().map(|(name, _)| name).collect::<HashSet<_>>();

        let used_names = objects
            .iter()
            .flat_map(|(_, object)| object.mentioned_names())
            .collect::<HashSet<_>>();

        let difference = defined_names.difference(&used_names).collect::<Vec<_>>();

        if difference.is_empty() {
            return Err(SceneParsingError::CycleDetected);
        }

        if *difference[0] != final_object_name {
            return Err(SceneParsingError::UnusedObject((*difference[0]).clone()));
        }

        if difference.len() > 1 {
            return Err(SceneParsingError::UnusedObject((*difference[1]).clone()));
        }

        Ok(())
    }

    /// returns true if a cycle exists in the scene graph
    fn contains_cycle(
        objects: &HashMap<&ObjectName, &Object>,
        final_object: &ObjectName,
    ) -> Result<(), SceneParsingError> {
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

            match &objects[name] {
                Object::Video(_) => Ok(()),
                Object::Texture(Texture { input, .. }) => visit(input, objects, visited),
                Object::Layout(Layout { inputs, .. }) => inputs
                    .values()
                    .map(|name| visit(name, objects, visited))
                    .collect::<Result<Vec<()>, SceneParsingError>>()
                    .map(|_| ()),
            }?;

            visited.insert(name.clone(), NodeState::Visited);

            Ok(())
        }

        let mut visited = HashMap::new();

        visit(final_object, objects, &mut visited)
    }

    pub fn validate(&self) -> Result<(), SceneParsingError> {
        Self::check_for_duplicate_pad_refs(&self.objects)?;

        Self::check_for_duplicate_or_undefined_names(&self.objects, &self.output)?;

        Self::check_for_unused_objects(&self.objects, &self.output)?;

        let objects = self
            .objects
            .iter()
            .map(|(name, object)| (name, object))
            .collect::<HashMap<_, _>>();

        Self::contains_cycle(&objects, &self.output)?;

        Ok(())
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
