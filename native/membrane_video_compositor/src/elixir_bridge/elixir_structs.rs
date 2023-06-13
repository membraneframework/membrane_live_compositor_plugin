use std::borrow::Borrow;
use std::collections::HashMap;
use std::sync::Arc;

use membrane_video_compositor_common::elixir_transfer::CustomStructElixirPacket;

use crate::scene::Node;

use super::scene_validation::{SceneParsingError, SceneValidator};

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.RustStructs.RawVideo"]
pub struct ElixirRawVideo {
    pub width: u32,
    pub height: u32,
    pub pixel_format: rustler::Atom,
    pub framerate: (u64, u64),
}

#[derive(Debug, Clone, Copy, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Resolution"]
pub struct Resolution {
    width: u32,
    height: u32,
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

/// A reference to a Membrane.Pad
pub type PadRef = String;

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

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Object.InputVideo.RustlerFriendly"]
pub struct InputVideo {
    pub input_pad: PadRef,
}

#[derive(rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Object.InputImage.RustlerFriendly"]
pub struct InputImage<'a> {
    pub frame: Frame<'a>,
    pub resolution: Resolution,
}

impl<'a> std::fmt::Debug for InputImage<'a> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("InputImage")
            .field("frame", &"<data>")
            .field("resolution", &self.resolution)
            .finish()
    }
}

/// It might be hard to figure out what this struct is for.
///
/// We need to get the `Binary` from rustler in some way. We can't use rustler types
/// in any type we want to use in tests, because erlang libraries and the BEAM, which are
/// necessary to use them, are not present in the process address space when running the
/// tests with `cargo test`.
///
/// This struct abstracts the concrete type of the source of the image, allowing any type
/// that can be borrowed as a `[u8]`. It also implements the `Decoder` and `Encoder` traits,
/// which allows rustler to automatically serialize and deserialize it, however it can be created
/// in a testing environment from a regular `[u8]`:
///
/// ```
/// let frame_data: [u8] = [1, 2, 3];
///
/// let frame = Frame(Box::new(frame_data));
/// ```
///
/// It is necessary for us to create a wrapper like this, since the orphan rule prevents us
/// from implementing `Decoder` and `Encoder` on `Box<dyn std::borrow::Borrow<[u8]> + 'a>`
pub struct Frame<'a>(Box<dyn std::borrow::Borrow<[u8]> + 'a>);

impl<'a> std::borrow::Borrow<[u8]> for Frame<'a> {
    fn borrow(&self) -> &[u8] {
        (*self.0).borrow()
    }
}

impl<'a> rustler::Decoder<'a> for Frame<'a> {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        Ok(Self(Box::new(rustler::Binary::from_term(term)?)))
    }
}

impl rustler::Encoder for Frame<'_> {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        let frame: &[u8] = self.borrow();

        let mut binary = rustler::OwnedBinary::new(frame.len())
            .expect("There is not enough free memory in the BEAM to return this back to elixir");

        // we need to copy all of the data to a new binary here, since the frame may not be an elixir
        // binary (e.g. it can just be a [u8])
        binary.as_mut().copy_from_slice(frame);

        binary.release(env).encode(env)
    }
}

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Object.Texture.RustlerFriendly"]
pub struct Texture {
    pub input: ObjectName,
    // this is a placeholder only temporarily, until we figure out encoding transformations
    // then, it will be something like `Arc<dyn Transformation>`
    pub transformations: Vec<CustomStructElixirPacket>,
    pub resolution: TextureOutputResolution,
}

impl Texture {
    pub fn mentioned_names(&self) -> Vec<&Name> {
        let mut names = self.previous_names();

        if let TextureOutputResolution::Name(name) = &self.resolution {
            names.push(name);
        }

        names
    }

    pub fn previous_names(&self) -> Vec<&Name> {
        vec![&self.input]
    }
}

#[derive(rustler::NifStruct, Debug)]
#[module = "Membrane.VideoCompositor.Object.Layout.RustlerFriendly"]
pub struct Layout {
    pub inputs: HashMap<LayoutInternalName, ObjectName>,
    pub resolution: LayoutOutputResolution,
    pub params: CustomStructElixirPacket,
}

impl Layout {
    pub fn mentioned_names(&self) -> Vec<&Name> {
        let mut names = self.previous_names();

        if let LayoutOutputResolution::Name(name) = &self.resolution {
            names.push(name);
        }

        names
    }

    pub fn previous_names(&self) -> Vec<&Name> {
        self.inputs.values().collect::<Vec<_>>()
    }
}

#[derive(Debug, rustler::NifTaggedEnum)]
pub enum Object<'a> {
    Layout(Layout),
    Texture(Texture),
    Video(InputVideo),
    Image(InputImage<'a>),
}

impl<'a> Object<'a> {
    pub fn mentioned_names(&self) -> Vec<&Name> {
        match self {
            Object::Layout(layout) => layout.mentioned_names(),
            Object::Texture(texture) => texture.mentioned_names(),
            Object::Video(_) | Object::Image(_) => Vec::new(),
        }
    }

    pub fn previous_names(&self) -> Vec<&Name> {
        match self {
            Object::Layout(layout) => layout.previous_names(),
            Object::Texture(texture) => texture.previous_names(),
            Object::Video(_) | Object::Image(_) => Vec::new(),
        }
    }
}

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Scene.RustlerFriendly"]
pub struct Scene<'a> {
    pub objects: Vec<(ObjectName, Object<'a>)>,
    pub output: ObjectName,
}

impl<'a> Scene<'a> {
    fn convert_to_graph(self) -> Result<Arc<Node>, SceneParsingError> {
        let mut objects = HashMap::from_iter(self.objects);

        let mut nodes = HashMap::new();

        fn parse_object(
            name: &ObjectName,
            nodes: &mut HashMap<ObjectName, Arc<Node>>,
            objects: &mut HashMap<ObjectName, Object>,
        ) -> Result<Arc<Node>, SceneParsingError> {
            if let Some(node) = nodes.get(name) {
                return Ok(node.clone());
            }

            let Some(object) = objects.remove(name) else {
                panic!("object {:?} not present in scene. expected since the scene passed validation.", name)
            };

            let node = match object {
                Object::Video(InputVideo { input_pad }) => Arc::new(Node::Video { pad: input_pad }),

                Object::Image(InputImage { frame, resolution }) => {
                    let frame: &[u8] = frame.borrow();

                    Arc::new(Node::Image {
                        data: frame.to_vec(),
                        resolution,
                    })
                }

                Object::Texture(Texture {
                    input,
                    transformations,
                    resolution,
                }) => {
                    let mut current = parse_object(&input, nodes, objects)?;

                    for transformation in transformations {
                        current = Arc::new(Node::Transformation {
                            previous: current,
                            transformation,
                            resolution: resolution.clone(),
                        });
                    }

                    current
                }

                Object::Layout(Layout {
                    inputs,
                    resolution,
                    params,
                }) => {
                    let inputs = inputs
                        .iter()
                        .map(|(internal_name, object_name)| {
                            parse_object(object_name, nodes, objects)
                                .map(|node| (internal_name.clone(), node))
                        })
                        .collect::<Result<HashMap<_, _>, _>>()?;

                    Arc::new(Node::Layout {
                        resolution,
                        params,
                        inputs,
                    })
                }
            };

            nodes.insert(name.clone(), node.clone());
            Ok(node)
        }

        parse_object(&self.output, &mut nodes, &mut objects)
    }
}

impl<'a> TryInto<crate::scene::Scene> for Scene<'a> {
    type Error = SceneParsingError;

    fn try_into(self) -> Result<crate::scene::Scene, Self::Error> {
        SceneValidator::new(&self).validate()?;

        let node = self.convert_to_graph()?;

        Ok(crate::scene::Scene { final_node: node })
    }
}

#[cfg(test)]
mod tests {
    use membrane_video_compositor_common::plugins::PluginRegistryKey;

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
                        params: unsafe {
                            CustomStructElixirPacket::encode(0, PluginRegistryKey("a"))
                        },
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
                        transformations: vec![
                            unsafe { CustomStructElixirPacket::encode(0, PluginRegistryKey("a")) },
                            unsafe { CustomStructElixirPacket::encode(0, PluginRegistryKey("b")) },
                            unsafe { CustomStructElixirPacket::encode(0, PluginRegistryKey("c")) },
                        ],
                    }),
                ),
            ],
            output: b,
        };

        let result: Result<crate::scene::Scene, _> = scene.try_into();
        let scene = result.unwrap();

        use crate::scene::Node;

        let final_node = scene.final_node;

        let Node::Transformation { ref previous, transformation, .. } = &*final_node else {
            panic!("unexpected scene structure");
        };
        assert_eq!(transformation.recipient_registry_key, "c");

        let Node::Transformation { ref previous, transformation, .. } = &**previous else {
            panic!("unexpected scene structure");
        };
        assert_eq!(transformation.recipient_registry_key, "b");

        let Node::Transformation { transformation, .. } = &**previous else {
            panic!("unexpected scene structure");
        };
        assert_eq!(transformation.recipient_registry_key, "a");
    }
}
