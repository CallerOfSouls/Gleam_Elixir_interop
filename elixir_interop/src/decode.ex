

defmodule Decode do

  def decode(a) do
    import Jason
    decode!(a)
  end
end
