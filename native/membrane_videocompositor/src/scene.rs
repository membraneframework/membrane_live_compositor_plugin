use crate::compositor::textures::RGBATexture;

pub trait Transformation {
    // this will be changed to a more proper trait, but I need a placeholder here
    fn inputs_amount(&self) -> usize {
        1
    }

    fn process(&self, textures: &[&RGBATexture]) -> &RGBATexture;
}

#[allow(unused)]
enum Node {
    Transformation {
        previous: Vec<Node>,
        transformation: Box<dyn Transformation>,
    },
    Video {
        id: usize,
    },
}

pub struct Scene {
    _final_node: Node,
}

// impl Scene {
//     pub fn traverse<'a>(&'a self, videos: &[(usize, &'a RGBATexture)]) -> &RGBATexture {
//         fn recurse<'a>(node: &'a Node, videos: &[(usize, &'a RGBATexture)]) -> &'a RGBATexture {
//             match node {
//                 Node::Transformation { previous, transformation } => {
//                     let inputs: Vec<&RGBATexture> = previous.iter().map(|node| recurse(node, videos)).collect();
//                     transformation.process(&inputs)
//                 }
//                 Node::Video { id } => {
//                     videos.iter().find(|(other_id, _)| *id == *other_id).unwrap().1
//                 }
//             }
//         }

//         recurse(&self.final_node, videos)
//     }
// }
