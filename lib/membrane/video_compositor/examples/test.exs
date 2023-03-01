alias Membrane.VideoCompositor.Examples.Mock.Layouts.Overlay
alias Membrane.VideoCompositor.Scene.Layout

# API I
# definition Overlay - "implements" "behavior" Layout from API I
@strip_overlay %Overlay{
  input_map: %{
    top_left: %Position{
      top_left_corner: {0.0, 0.0},
      width: @sixteen_tenths * @one_third,
      height: @one_third,
      z_value: 1.0
    },
    center_left: %Position{
      top_left_corner: {0.0, @one_third},
      width: @sixteen_tenths * @one_third,
      height: @one_third,
      z_value: 1.0
    },
    bottom_left: %Position{
      top_left_corner: {0.0, 2 * @one_third},
      width: @sixteen_tenths * @one_third,
      height: @one_third,
      z_value: 1.0
    },
    background: %Position{
      top_left_corner: {0.0, 0.0},
      width: 1.0,
      height: 1.0,
      z_value: 0.0
    }
  }
}

# usage - in API I each implementation of Layout has to be wrapped with %Layout{}
%Scene{
  objects: [
    final_object: %Layout{
      inputs_map: %{
        top_left: :video_1,
        center_left: :video_2,
        bottom_left: :video_3,
        background: :video_4
      },
      layout: @strip_overlay,
      resolution: %Resolution{width: 1920, height: 1080}
    }
  ],
  output: :final_object
}

# API II
# definition OverlayBetter - "implements" "behaviour" Layout from API II
@strip_overlay_better %OverlayBetter{
  # specific to OverlayBetter
  some_overlay_spec: %{
    top_left: %Position{
      top_left_corner: {0.0, 0.0},
      width: @sixteen_tenths * @one_third,
      height: @one_third,
      z_value: 1.0
    },
    center_left: %Position{
      top_left_corner: {0.0, @one_third},
      width: @sixteen_tenths * @one_third,
      height: @one_third,
      z_value: 1.0
    },
    bottom_left: %Position{
      top_left_corner: {0.0, 2 * @one_third},
      width: @sixteen_tenths * @one_third,
      height: @one_third,
      z_value: 1.0
    },
    background: %Position{
      top_left_corner: {0.0, 0.0},
      width: 1.0,
      height: 1.0,
      z_value: 0.0
    }
  },
  # used in every layout struct
  inputs: %{
    top_left: nil,
    center_left: nil,
    bottom_left: nil,
    background: nil
  },
  resolution: %Resolution{width: 1920, height: 1080}
}

# usage - in API II we don't wrap implementations of Layout
%Scene{
  objects: [
    final_object: %OverlayBetter{
      @strip_overlay_better
      | inputs: %{
          top_left: :video_1,
          center_left: :video_2,
          bottom_left: :video_3,
          background: :video_4
        }
    }
  ],
  output: :final_object
}
