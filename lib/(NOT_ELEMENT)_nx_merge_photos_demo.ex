defmodule NxMergePhotos do
  @moduledoc """
  Module, that tests simple image merging in Nx.
  """
  def merge(first_photo_path, second_photo_path) do
    EXLA.set_as_nx_default([:tpu, :cuda, :rocm, :host])
    {:ok, first_image} = Vix.Vips.Image.new_from_file(first_photo_path)
    {:ok, second_image} = Vix.Vips.Image.new_from_file(second_photo_path)

    {:ok, first_image_nxtensor} = Image.to_nx(first_image)
    {:ok, second_image_nxtensor} = Image.to_nx(second_image)


    {width, height, bands} = Nx.shape(first_image_nxtensor)

    merged_nxtensor =
    Nx.stack([first_image_nxtensor, second_image_nxtensor]) # place first frame above second, but adds dimension
    |> Nx.flatten()  # to remove added dimension
    |> Nx.reshape({width, height * 2, bands}, names: [:width, :height, :bands])  # to remove added dimension

    # {:ok, merged_nxtensor} = nx_tensors_merging(first_image_nxtensor, second_image_nxtensor, Nx.shape(first_image_nxtensor))

    {:ok, merged_image} = Image.from_nx(merged_nxtensor)

    Vix.Vips.Image.write_to_file(merged_image, "merged.png")

    {:ok, merged_image, merged_nxtensor}
  end
end
