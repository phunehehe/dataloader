defmodule DataLoader.Ecto do
  defstruct [
    :repo,
    :caller,
    batches: %{},
    results: %{},
  ]

  def new(repo) do
    %__MODULE__{
      repo: repo,
      caller: self(),
    }
  end

  defimpl DataLoader.Source do
    def add(source, batch_key, item_key, item) do
      update_in(source.batches, fn batches ->
        entry = {item_key, item}
        Map.update(batches, batch_key, [entry], &[entry | &1])
      end)
    end

    def run(source) do
      results = Map.new(source.batches, &run_batch(&1, source))
      # TODO: deep merge results
      %{source | results: results, batches: %{}}
    end

    def get_result(%{results: results}, batch_key, item_key) do
      results[batch_key][item_key]
    end

    def pending_batches?(%{batches: batches}) do
      batches != %{}
    end

    defp run_batch({assoc, items}, source) do
      {item_keys, items} = Enum.unzip(items)
      results =
        items
        |> source.repo.preload([assoc], caller: source.caller)
        |> Enum.map(&Map.get(&1, assoc))
      batch_results = Enum.zip(item_keys, results)
      {assoc, Map.new(batch_results)}
    end
  end
end
