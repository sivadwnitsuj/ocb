defmodule Maven do
  alias Porcelain.Process, as: Proc

  @moduledoc """
  Run Maven.
  """

  defmodule Result do
    @moduledoc """
    Result of running Maven.
    """

    defstruct [:status, :exit, :filtered]

    @type t :: %__MODULE__{}
  end

  @mvn "mvn"

  @doc """
  """
  @spec mvn(list(String.t), (String.t -> list)) :: Maven.Result.t
  def mvn(mvn_opts, filter \\ &([&1])) do
    # it is important to :keep the result, otherwise
    # you cannot wait for it
    proc = Porcelain.spawn(@mvn, mvn_opts, out: :stream, result: :keep)
    filtered = proc.out
      |> Stream.map(&String.strip(&1))
      |> Stream.each(&IO.puts(&1))
      |> Stream.flat_map(&filter.(&1))
      |> Enum.into([])
    # await Maven to finish and transform the return code
    case Proc.await(proc) do
      {:ok, %Porcelain.Result{status: 0}} ->
        %Result{status: :ok, exit: nil, filtered: filtered}
      {:ok, %Porcelain.Result{status: exit}} ->
        %Result{status: :error, exit: exit, filtered: filtered}
      # crash otherwise
    end
  end

  @regex ~r/^\[INFO\] Installing (.*?\.jar) to .*?\.jar$/
  def filter_find_install_jar(line) do
    match = @regex |> Regex.run(line)
    case match do
      nil -> []
      [_, jar] -> [jar]
    end
  end
end