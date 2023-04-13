#![allow(clippy::needless_borrow)]
#![allow(clippy::from_over_into)]
use std::collections::HashMap;
use std::sync::Arc;

use rustler::NifUntaggedEnum;

use crate::compositor::math::Vec2d;
use crate::compositor::texture_transformations::corners_rounding::CornersRounding;
use crate::compositor::texture_transformations::cropping::Cropping;
use crate::compositor::texture_transformations::TextureTransformation;
use crate::compositor::{self, VideoPlacement};
use crate::elixir_bridge::{atoms, convert_z};
use crate::scene::Node;

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.RustStructs.RawVideo"]
pub struct ElixirRawVideo {
    pub width: u32,
    pub height: u32,
    pub pixel_format: rustler::Atom,
    pub framerate: (u64, u64),
}

#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.RustStructs.BaseVideoPlacement"]
pub struct ElixirBaseVideoPlacement {
    pub position: (i32, i32),
    pub size: (u32, u32),
    pub z_value: f32,
}

impl Into<VideoPlacement> for ElixirBaseVideoPlacement {
    fn into(self) -> VideoPlacement {
        compositor::VideoPlacement {
            position: Vec2d {
                x: self.position.0,
                y: self.position.1,
            },
            size: Vec2d {
                x: self.size.0,
                y: self.size.1,
            },
            z: convert_z(self.z_value),
        }
    }
}

/// Describes all transformations applied to video
#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.VideoTransformations"]
pub struct ElixirVideoTransformations {
    pub texture_transformations: Vec<ElixirTextureTransformations>,
}

impl Into<Vec<Box<dyn TextureTransformation>>> for ElixirVideoTransformations {
    fn into(self) -> Vec<Box<dyn TextureTransformation>> {
        let mut texture_transformations = Vec::new();

        for texture_transformation in self.texture_transformations.into_iter() {
            texture_transformations.push(texture_transformation.into());
        }

        texture_transformations
    }
}

/// Wraps video transformations parameters (wrapped in structs) into enum.
/// Allows passing to rust elixir texture transformation type,
/// which is algebraic sum type of all structs describing single
/// texture transformation.
/// As a developer adding new texture transformation, you need just to add
/// new enum value and implement new match arm converting elixir structs to
/// rust structs used in shader.
#[derive(Debug, NifUntaggedEnum, Clone, Copy)]
pub enum ElixirTextureTransformations {
    CornersRounding(ElixirCornersRounding),
    Cropping(ElixirCropping),
}

impl Into<Box<dyn TextureTransformation>> for ElixirTextureTransformations {
    fn into(self) -> Box<dyn TextureTransformation> {
        match self {
            ElixirTextureTransformations::CornersRounding(elixir_corners_rounding) => {
                elixir_corners_rounding.into()
            }
            ElixirTextureTransformations::Cropping(elixir_cropping) => elixir_cropping.into(),
        }
    }
}

/// Elixir struct wrapping parameters describing corner rounding texture transformation
#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding"]
pub struct ElixirCornersRounding {
    pub border_radius: u32,
}

impl Into<Box<dyn TextureTransformation>> for ElixirCornersRounding {
    fn into(self) -> Box<dyn TextureTransformation> {
        Box::new(CornersRounding {
            border_radius: self.border_radius as f32,
            video_width: 0.0,  // will be updated in compositor
            video_height: 0.0, // will be updated in compositor
        })
    }
}

/// Elixir struct wrapping parameters describing cropping texture transformation
#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping"]
pub struct ElixirCropping {
    pub crop_top_left_corner: (f32, f32),
    pub crop_size: (f32, f32),
    pub cropped_video_position: rustler::Atom,
}

impl From<ElixirCropping> for Box<dyn TextureTransformation> {
    fn from(val: ElixirCropping) -> Self {
        let transform_position: bool;

        if val.cropped_video_position == atoms::crop_part_position() {
            transform_position = true;
        } else if val.cropped_video_position == atoms::input_position() {
            transform_position = false;
        } else {
            panic!("Unsupported elixir positioning format");
        }

        Box::new(Cropping::new(
            Vec2d {
                x: val.crop_top_left_corner.0,
                y: val.crop_top_left_corner.1,
            },
            Vec2d {
                x: val.crop_size.0,
                y: val.crop_size.1,
            },
            transform_position,
        ))
    }
}

#[derive(Debug, Clone, Copy, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Scene.Resolution"]
pub struct Resolution {
    width: u32,
    height: u32,
}

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Scene.Object.Texture.RustlerFriendly"]
pub struct Texture {
    pub input: ObjectName,
    // this is a placeholder only temporarily, until we figure out encoding transformations
    // then, it will be something like `Arc<dyn Transformation>`
    pub transformations: Vec<ImplementationPlaceholder>,
    pub resolution: TextureOutputResolution,
}

#[derive(rustler::NifTaggedEnum, PartialEq, Eq, Hash, Clone)]
pub enum Name {
    Atom(String),
    AtomPair(String, String),
    AtomNum(String, u64),
}

impl std::fmt::Debug for Name {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Atom(atom) => f.write_fmt(format_args!(":{atom}")),
            Self::AtomPair(atom1, atom2) => f.write_fmt(format_args!("{{:{atom1}, :{atom2}}}")),
            Self::AtomNum(atom1, num) => f.write_fmt(format_args!("{{:{atom1}, {num}}}")),
        }
    }
}

pub type ObjectName = Name;
pub type LayoutInternalName = Name;
pub type ImplementationPlaceholder = usize;

#[derive(rustler::NifStruct, Debug)]
#[module = "Membrane.VideoCompositor.Scene.Object.Layout.RustlerFriendly"]
pub struct Layout {
    pub inputs: HashMap<LayoutInternalName, ObjectName>,
    pub resolution: LayoutOutputResolution,
    pub implementation: ImplementationPlaceholder,
}

#[derive(Debug, rustler::NifTaggedEnum, Clone)]
pub enum TextureOutputResolution {
    TransformedInputResolution,
    Resolution(Resolution),
    Name(ObjectName),
}

#[derive(Debug, rustler::NifTaggedEnum, Clone)]
pub enum LayoutOutputResolution {
    Resolution(Resolution),
    Name(ObjectName),
}

#[derive(Debug, rustler::NifTaggedEnum)]
pub enum Object {
    Layout(Layout),
    Texture(Texture),
    Video(InputVideo),
}

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Scene.RustlerFriendly"]
pub struct Scene {
    pub objects: Vec<(ObjectName, Object)>,
    pub output: ObjectName,
}

impl Scene {
    fn convert_to_graph(self) -> Result<Arc<Node>, SceneParsingError> {
        let objects = HashMap::from_iter(self.objects);

        let mut nodes = HashMap::new();
        let final_object = &objects[&self.output];

        fn parse_object(
            name: &ObjectName,
            object: &Object,
            nodes: &mut HashMap<ObjectName, Arc<Node>>,
            objects: &HashMap<ObjectName, Object>,
        ) -> Result<Arc<Node>, SceneParsingError> {
            if let Some(node) = nodes.get(name) {
                return Ok(node.clone());
            }

            match object {
                Object::Video(InputVideo { input_pad }) => {
                    let node = Arc::new(Node::Video {
                        pad: input_pad.clone(),
                    });
                    nodes.insert(name.clone(), node.clone());
                    Ok(node)
                }

                Object::Texture(Texture {
                    input,
                    transformations,
                    resolution,
                }) => {
                    let mut current = parse_object(input, &objects[input], nodes, objects)?;

                    // we may need to get ownership of the transformation here later on in the project.
                    // this means that we'll most likely need to remove `object` from `objects`, but since it's not certain
                    // I'm leaving it as is for now
                    for &transformation in transformations {
                        current = Arc::new(Node::Transformation {
                            previous: current,
                            transformation,
                            resolution: resolution.clone(),
                        });
                    }

                    nodes.insert(name.clone(), current.clone());

                    Ok(current)
                }

                Object::Layout(Layout {
                    inputs,
                    resolution,
                    implementation,
                }) => {
                    let inputs = inputs
                        .iter()
                        .map(|(internal_name, object_name)| {
                            parse_object(
                                object_name,
                                objects.get(object_name).ok_or_else(|| {
                                    SceneParsingError::UndefinedName(object_name.clone())
                                })?,
                                nodes,
                                objects,
                            )
                            .map(|node| (internal_name.clone(), node))
                        })
                        .collect::<Result<HashMap<_, _>, _>>()?;

                    let result = Arc::new(Node::Layout {
                        resolution: resolution.clone(),
                        implementation: *implementation,
                        inputs,
                    });
                    nodes.insert(name.clone(), result.clone());
                    Ok(result)
                }
            }
        }

        parse_object(&self.output, &final_object, &mut nodes, &objects)
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

impl TryInto<crate::scene::Scene> for Scene {
    type Error = SceneParsingError;

    fn try_into(self) -> Result<crate::scene::Scene, Self::Error> {
        self.validate()?;

        let node = self.convert_to_graph()?;

        Ok(crate::scene::Scene { final_node: node })
    }
}

/// A reference to a Membrane.Pad
pub type PadRef = String;

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Scene.Object.InputVideo.RustlerFriendly"]
pub struct InputVideo {
    pub input_pad: PadRef,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scene_parsing_simple_success() {
        let a = Name::Atom("a".into());
        let b = Name::Atom("b".into());
        let c = Name::Atom("c".into());

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
            ],
            output: c,
        };

        let result: Result<crate::scene::Scene, _> = scene.try_into();
        assert!(result.is_ok())
    }

    #[test]
    fn scene_parsing_maintains_transformation_order() {
        let a = Name::Atom("a".into());
        let b = Name::Atom("b".into());

        let scene = Scene {
            objects: vec![
                (
                    a.clone(),
                    Object::Video(InputVideo {
                        input_pad: "pad1".into(),
                    }),
                ),
                (
                    b.clone(),
                    Object::Texture(Texture {
                        input: a,
                        resolution: TextureOutputResolution::TransformedInputResolution,
                        transformations: vec![0, 1, 2],
                    }),
                ),
            ],
            output: b,
        };

        let result: Result<crate::scene::Scene, _> = scene.try_into();
        let scene = result.unwrap();

        use crate::scene::Node;

        let final_node = scene.final_node;

        let Node::Transformation { ref previous, transformation, .. } = *final_node else {
            panic!("unexpected scene structure");
        };
        assert_eq!(transformation, 2);

        let Node::Transformation { ref previous, transformation, .. } = **previous else {
            panic!("unexpected scene structure");
        };
        assert_eq!(transformation, 1);

        let Node::Transformation { transformation, .. } = **previous else {
            panic!("unexpected scene structure");
        };
        assert_eq!(transformation, 0);
    }
}
