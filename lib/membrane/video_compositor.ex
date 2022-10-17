defmodule Membrane.VideoCompositor do
  @moduledoc """
  The element responsible for placing the first received frame
  above the other and sending forward buffer with
  merged frame binary in the payload.
  """

  use Membrane.Filter
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Implementations
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.ComponentsManager, as: Manager
  alias Membrane.VideoCompositor.Scene.ElementDescription
  alias Membrane.VideoCompositor.Track

  def_options implementation: [
                spec: Implementations.implementation_t() | {:mock, module()},
                description: "Implementation of video composer."
              ],
              caps: [
                spec: RawVideo.t(),
                description: "Struct with video width, height, framerate and pixel format."
              ],
              scene: [
                spec: ElementDescription.entries_t(),
                description: "Description of the video composition"
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    availability: :on_request,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420},
    options: [
      id: [
        spec: pos_integer() | nil,
        description: "ID used to distinguish input videos on the scene",
        default: nil
      ]
    ]

  def_output_pad :output,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}

  @impl true
  def handle_init(options) do
    compositor_module = determine_compositor_module(options.implementation)

    {:ok, internal_state} = compositor_module.init(options.caps)

    if Keyword.has_key?(options.scene, :size) do
      raise ArgumentError,
        message:
          "Top scene given to the compositor should not have `:size` property initialized. It is automatically set to the caps' dimensions."
    end

    scene =
      Keyword.put(options.scene, :size, %{width: options.caps.width, height: options.caps.height})

    {scene, manager} = Scene.init(scene, %Manager{})

    state = %{
      caps: options.caps,
      compositor_module: compositor_module,
      internal_state: internal_state,
      scene: scene,
      manager: manager,
      pads_to_ids: %{},
      ids_to_tracks: %{},
      ignored_ids_to_tracks: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, caps: {:output, state.caps}}, state}
  end

  @impl true
  def handle_pad_added(pad, context, state) do
    id = context.options.id

    state = register_track(state, pad, id)
    {:ok, state}
  end

  defp register_track(state, pad, id) do
    state = %{
      state
      | pads_to_ids: Map.put(state.pads_to_ids, pad, id)
    }

    if Scene.video_registered?(state.scene, id) do
      %{state | ids_to_tracks: Map.put(state.ids_to_tracks, id, %Track{})}
    else
      %{state | ignored_ids_to_tracks: Map.put(state.ignored_ids_to_tracks, id, %Track{})}
    end
  end

  @impl true
  def handle_other({:scene, scene}, _context, state) do
    state = set_scene(state, scene)
    {:ok, state}
  end

  defp set_scene(_state, _scene) do
    # raise "not_implemented"
  end

  @impl true
  def handle_caps(pad, caps, _context, state) do
    %{
      pads_to_ids: pads_to_ids,
      internal_state: internal_state,
      scene: scene
    } = state

    id = Map.get(pads_to_ids, pad)

    if Scene.video_registered?(scene, id) do
      position = Scene.video_position(scene, id)

      {:ok, internal_state} =
        state.compositor_module.add_video(internal_state, id, caps, position)

      state = %{state | internal_state: internal_state}
      {:ok, state}
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_process(
        pad,
        buffer,
        _context,
        state
      ) do
    %{
      ids_to_tracks: ids_to_tracks,
      pads_to_ids: pads_to_ids,
      scene: scene
    } = state

    id = Map.get(pads_to_ids, pad)

    ids_to_tracks =
      if Scene.video_registered?(scene, id) do
        push_frame(ids_to_tracks, id, buffer)
      else
        ids_to_tracks
      end

    state = %{
      state
      | ids_to_tracks: ids_to_tracks
    }

    case merge_frames(state) do
      {{:merged, buffers}, state} -> {{:ok, buffer: {:output, buffers}}, state}
      {{:empty, _empty}, state} -> {:ok, state}
    end
  end

  defp merge_frames(state) do
    %{
      ids_to_tracks: ids_to_tracks,
      internal_state: internal_state
    } = state

    if all_tracks_ready_to_merge?(ids_to_tracks) do
      ids_to_frames = get_ids_to_frames(ids_to_tracks)

      {{:ok, merged_frame_binary}, internal_state} =
        state.compositor_module.merge_frames(internal_state, ids_to_frames)

      ids_to_tracks = pop_frames(ids_to_tracks)

      state = %{
        state
        | ids_to_tracks: ids_to_tracks,
          internal_state: internal_state
      }

      state = remove_finished_tracks(state)

      {{_status, tail}, state} = merge_frames(state)
      merged = [%Membrane.Buffer{payload: merged_frame_binary}] ++ tail

      {{:merged, merged}, state}
    else
      {{:empty, []}, state}
    end
  end

  defp push_frame(ids_to_tracks, id, frame) do
    Map.update!(ids_to_tracks, id, fn track ->
      Track.push_frame(track, frame)
    end)
  end

  defp all_tracks_ready_to_merge?(ids_to_tracks) when map_size(ids_to_tracks) == 0 do
    false
  end

  defp all_tracks_ready_to_merge?(ids_to_tracks) do
    ids_to_tracks
    |> Map.values()
    |> Enum.all?(&Track.has_frame?/1)
  end

  defp get_ids_to_frames(ids_to_tracks) do
    ids_to_tracks
    |> Enum.map(fn {id, %Track{} = track} -> {id, Track.first_frame(track)} end)
    |> Enum.sort()
  end

  defp pop_frames(ids_to_tracks) do
    ids_to_tracks
    |> Enum.map(fn {id, %Track{} = track} ->
      {id, Track.pop_frame(track)}
    end)
    |> Map.new()
  end

  defp remove_finished_tracks(state) do
    state.ids_to_tracks
    |> Enum.reduce(
      state,
      fn {id, %Track{} = track}, state ->
        if Track.finished?(track) do
          remove_track(state, id)
        else
          state
        end
      end
    )
  end

  defp track_finished?(ids_to_tracks, id) do
    track = Map.get(ids_to_tracks, id)
    Track.finished?(track)
  end

  defp remove_track(state, id) do
    %{ids_to_tracks: ids_to_tracks, internal_state: internal_state} = state
    ids_to_tracks = Map.delete(ids_to_tracks, id)
    {:ok, internal_state} = state.compositor_module.remove_video(internal_state, id)
    %{state | ids_to_tracks: ids_to_tracks, internal_state: internal_state}
  end

  defp update_track_status(ids_to_tracks, id, status) do
    ids_to_tracks
    |> Map.update!(id, fn track -> %Track{track | status: status} end)
  end

  defp tracks_status(ids_to_tracks) do
    if Map.values(ids_to_tracks) |> Enum.all?(&Track.finished?/1) do
      :all_finished
    else
      :still_ongoing
    end
  end

  @impl true
  def handle_end_of_stream(
        pad,
        _context,
        state
      ) do
    %{ids_to_tracks: ids_to_tracks, pads_to_ids: pads_to_ids} = state
    id = Map.get(pads_to_ids, pad)

    ids_to_tracks = ids_to_tracks |> update_track_status(id, :end_of_stream)
    state = %{state | ids_to_tracks: ids_to_tracks}

    state =
      if track_finished?(ids_to_tracks, id) do
        remove_track(state, id)
      else
        state
      end

    {{buffers_status, buffers}, state} = merge_frames(state)

    case {buffers_status, tracks_status(state.ids_to_tracks)} do
      {:empty, :still_ongoing} ->
        {:ok, state}

      {:empty, :all_finished} ->
        {{:ok, end_of_stream: :output}, state}

      {:merged, :still_ongoing} ->
        {{:ok, buffer: {:output, buffers}}, state}

      {:merged, :all_finished} ->
        {{:ok, buffer: {:output, buffers}, end_of_stream: :output}, state}
    end
  end

  defp determine_compositor_module(implementation) do
    case implementation do
      {:mock, module} ->
        module

      implementation ->
        case Implementations.get_implementation_module(implementation) do
          {:ok, module} -> module
          {:error, error} -> raise error
        end
    end
  end
end
