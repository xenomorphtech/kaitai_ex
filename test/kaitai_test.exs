defmodule KaitaiTest do
  use ExUnit.Case
  doctest Kaitai

  test "greets the world" do
    simple = """
    meta:
      id: gif
      file-extension: gif
      endian: le
    seq:
      - id: header
        type: header
      - id: logical_screen
        type: logical_screen
    types:
      header:
        seq:
          - id: magic
            contents: 'GIF'
          - id: version
            size: 3
      logical_screen:
        seq:
          - id: image_width
            type: u2
          - id: image_height
            type: u2
          - id: flags
            type: u1
          - id: bg_color_index
            type: u1
          - id: pixel_aspect_ratio
            type: u1
    """

    {:ok, simple} = YamlElixir.read_from_string(simple)

    meta = simple["meta"]
    # sequential elements
    seq = simple["seq"]

    types = simple["types"]

    types_comp =
      Enum.map(types, fn {type_name, data} ->
        # each type must have a seq?
        seq = data["seq"]
        # each element must have an id, and either size or type
        seq1 =
          Enum.map(seq, fn seq ->
            id = seq["id"]
            type = seq["type"]
            size = seq["size"]
            contents = seq["contents"]

            dec =
              cond do
                !!contents ->
                  "<<#{inspect(contents)} :: binary, rest::binary>> = rest"

                !!type ->
                  "{#{id}, rest} = decode_#{type}(rest)"

                !!size ->
                  "<<#{id} :: binary-size(#{size}), rest::binary>> = rest"

                true ->
                  throw("no type or size field #{inspect(seq)}")
              end

            {id, dec}
          end)

        seq2 =
          Enum.map(seq1, fn {id, dec} ->
            "#{id}: #{id},"
          end)

        seq_dec =
          Enum.map(seq1, fn {id, dec} ->
            dec
          end)

        code = ["def decode_#{type_name}(rest) do", seq_dec, "%{", seq2, "%}", "end"]
        Enum.join(List.flatten(code), "\n")
      end)

    IO.puts(Enum.join(types_comp, "\n\n"))
  end
end
