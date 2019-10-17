defmodule Drtree do
  use GenServer

  defstruct metadata: nil,
            tree: nil,
            listeners: [],
            crdt: nil

  @moduledoc """
  This is the API module of the elixir r-tree implementation where you can do the basic actions.


  ## Easy to use:

    Starts a local r-tree named as Peter
      iex> DDRT.start_link(%{name: Peter})
      {:ok, #PID<0.214.0>}

    Insert "Griffin" on r-tree named as Peter
      iex> Drtree.insert({"Griffin",[{4,5},{6,7}]},Peter)
      {:ok,
      %{
       43143342109176739 => {["Griffin"], nil, [{4, 5}, {6, 7}]},
       :root => 43143342109176739,
       :ticket => [19125803434255161 | 82545666616502197],
       "Griffin" => {:leaf, 43143342109176739, [{4, 5}, {6, 7}]}
      }}


    Insert "Parker" on r-tree named as Peter
      iex> Drtree.insert({"Parker",[{10,11},{16,17}]},Peter)
      {:ok,
      %{
       43143342109176739 => {["Parker", "Griffin"], nil, [{4, 11}, {6, 17}]},
       :root => 43143342109176739,
       :ticket => [19125803434255161 | 82545666616502197],
       "Griffin" => {:leaf, 43143342109176739, [{4, 5}, {6, 7}]},
       "Parker" => {:leaf, 43143342109176739, [{10, 11}, {16, 17}]}
      }}


    Query which leafs at Peter r-tree overlap with box `[{0,7},{4,8}]`
      iex> Drtree.query([{0,7},{4,8}],Peter)
      {:ok, ["Griffin"]}

    Updates "Griffin" bounding box
      iex> Drtree.update("Griffin",[{-6,-5},{11,12}],Peter)
      {:ok,
      %{
       43143342109176739 => {["Parker", "Griffin"], nil, [{-6, 11}, {6, 17}]},
       :root => 43143342109176739,
       :ticket => [19125803434255161 | 82545666616502197],
       "Griffin" => {:leaf, 43143342109176739, [{-6, -5}, {11, 12}]},
       "Parker" => {:leaf, 43143342109176739, [{10, 11}, {16, 17}]}
      }}

    Repeat again the last query
      iex> Drtree.query([{0,7},{4,8}],Peter)
      {:ok, []} # Peter "Griffin" left the query bounding box

    Let's punish them
      iex> Drtree.delete(["Griffin","Parker"],Peter)
      {:ok,
      %{
       43143342109176739 => {[], nil, [{0, 0}, {0, 0}]},
       :root => 43143342109176739,
       :ticket => [19125803434255161 | 82545666616502197]
      }}

  ## Easy concepts:

    Bounding box format.

    `[{x_min,x_max},{y_min,y_max}]`

              Example:                               & & & & & y_max & & & & &
                A unit at pos x: 10, y: -12 ,        &                       &
                with x_size: 1 and y_size: 2         &                       &
                would be represented with            &          pos          &
                the following bounding box         x_min       (x,y)       x_max
                [{9.5,10.5},{-13,-11}]               &                       &
                                                     &                       &
                                                     &                       &
                                                     & & & & & y_min & & & & &

  """
  @type coord_range :: {number(),number()}
  @type bounding_box :: list(coord_range())
  @type id :: number() | String.t()
  @type leaf :: {id(),bounding_box()}
  @doc false
  @spec rinsert(map(),tuple())::map()
  defdelegate rinsert(tree,leaf), to: ElixirRtree
  @doc false
  @spec bquery(map(),bounding_box)::list(integer())
  defdelegate bquery(tree,box), to: ElixirRtree
  @doc false
  @spec bquery(map(),bounding_box,integer())::list(integer())
  defdelegate bquery(tree,box,depth), to: ElixirRtree
  @doc false
  @spec rdelete(map(),any())::map()
  defdelegate rdelete(tree,id), to: ElixirRtree
  @doc false
  @spec rupdate_leaf(map(),any(),{bounding_box,bounding_box} | {bounding_box})::map()
  defdelegate rupdate_leaf(tree,id,update), to: ElixirRtree

  @opt_values %{
    type: [Map,MerkleMap],
    mode: [:standalone, :distributed]
  }

  @defopts %{
    width: 6,
    type: Map,
    mode: :standalone,
    verbose: false,
    seed: 0
  }

  @spec new(map(),atom())::{:ok,map()}
  @doc false
  def new(opts \\ @defopts,name \\ __MODULE__)when is_map(opts)do
    GenServer.call(name,{:new,opts})
  end

  def insert(_a,name \\ __MODULE__)
  @doc """
    Insert `leafs` at the r-tree named as `name`

    Returns `{:ok,map()}`

  ## Parameters

    - `leafs`: the data to insert.
    - `name`: the r-tree name where you wanna insert.

  ## Examples
    1 by 1.
      iex> Drtree.insert({"Griffin",[{4,5},{6,7}]},Peter)
      iex> Drtree.insert({"Parker",[{14,15},{16,17}]},Peter)

      {:ok,
      %{
       43143342109176739 => {["Parker", "Griffin"], nil, [{4, 15}, {6, 17}]},
       :root => 43143342109176739,
       :ticket => [19125803434255161 | 82545666616502197],
       "Griffin" => {:leaf, 43143342109176739, [{4, 5}, {6, 7}]},
       "Parker" => {:leaf, 43143342109176739, [{14, 15}, {16, 17}]}
      }}


    Bulk.
      iex> Drtree.insert([{"Griffin",[{4,5},{6,7}]},{"Parker",[{14,15},{16,17}]}],Peter)

      {:ok,
      %{
       43143342109176739 => {["Parker", "Griffin"], nil, [{4, 15}, {6, 17}]},
       :root => 43143342109176739,
       :ticket => [19125803434255161 | 82545666616502197],
       "Griffin" => {:leaf, 43143342109176739, [{4, 5}, {6, 7}]},
       "Parker" => {:leaf, 43143342109176739, [{14, 15}, {16, 17}]}
      }}


  """
  @spec insert(leaf() | list(leaf()),atom())::{:ok,map()}
  def insert(leafs,name)when is_list(leafs)do
    GenServer.call(name,{:bulk_insert,leafs},:infinity)
  end
  def insert(leaf, name)do
    GenServer.call(name,{:insert,leaf},:infinity)
  end

  @doc """
    Query to get every leaf id overlapped by `box`.

    Returns `[id's]`.

  ## Examples

      iex> Drtree.query([{0,7},{4,8}],Peter)
      {:ok, ["Griffin"]}

  """
  @spec query(bounding_box(),atom())::list(id())
  def query(box,name \\ __MODULE__)do
    GenServer.call(name,{:query,box})
  end

  @doc """
    Query to get every node id overlapped by `box` at the defined `depth`.

    Returns `[id's]`.
  """
  @spec pquery(bounding_box(),integer(),atom())::list(id())
  def pquery(box,depth,name \\ __MODULE__)do
    GenServer.call(name,{:query_depth,{box,depth}})
  end

  def delete(_a,name \\ __MODULE__)
  @doc """
  Delete the leafs with the given `ids`.

  Returns `{:ok,map()}`

  ## Parameters

    - `ids`: Id or list of Id that you wanna delete.
    - `name`: the r-tree name where you wanna delete.

  ## Examples
    1 by 1.
      iex> Drtree.delete("Griffin",Peter)
      iex> Drtree.delete("Parker",Peter)

    Bulk.
      iex> Drtree.delete(["Griffin","Parker"],Peter)
  """
  @spec delete(id() | list(id()),atom())::{:ok,map()}
  def delete(ids, name)when is_list(ids)do
    GenServer.call(name,{:bulk_delete,ids},:infinity)
  end
  def delete(id, name)do
    GenServer.call(name,{:delete,id})
  end

  @doc """
  Update a bunch of r-tree leafs to the new bounding boxes defined.

  Returns `{:ok,map()}`

  ## Examples

      iex> Drtree.updates([{"Griffin",[{0,1},{0,1}]},{"Parker",[{10,11},{10,11}]}],Peter)

      {:ok,
      %{
       43143342109176739 => {["Parker", "Griffin"], nil, [{0, 11}, {0, 11}]},
       :root => 43143342109176739,
       :ticket => [19125803434255161 | 82545666616502197],
       "Griffin" => {:leaf, 43143342109176739, [{0, 1}, {0, 1}]},
       "Parker" => {:leaf, 43143342109176739, [{10, 11}, {10, 11}]}
      }}

  """
  @spec updates(list(leaf()),atom())::{:ok,map()}
  def updates(updates,name \\ __MODULE__)when is_list(updates)do
    GenServer.call(name,{:bulk_update,updates},:infinity)
  end

  @doc """
  Update a single leaf bounding box

  Returns `{:ok,map()}`

  ## Examples

      iex> Drtree.update({"Griffin",[{0,1},{0,1}]},Peter)

      {:ok,
      %{
       43143342109176739 => {["Parker", "Griffin"], nil, [{0, 11}, {0, 11}]},
       :root => 43143342109176739,
       :ticket => [19125803434255161 | 82545666616502197],
       "Griffin" => {:leaf, 43143342109176739, [{0, 1}, {0, 1}]},
       "Parker" => {:leaf, 43143342109176739, [{10, 11}, {16, 17}]}
      }}

  """
  @spec update(id(), bounding_box() | {bounding_box(),bounding_box()},atom())::{:ok,map()}
  def update(id,update,name \\ __MODULE__)do
    GenServer.call(name,{:update,{id,update}})
  end

  @doc """
  Get the r-tree metadata

  Returns `map()`

  ## Examples

      iex> Drtree.metadata(Peter)

      %{
        params: %{mode: :standalone, seed: 0, type: Map, verbose: false, width: 6},
        seeding: %{
          bits: 58,
          jump: #Function<3.53802439/1 in :rand.mk_alg/1>,
          next: #Function<0.53802439/1 in :rand.mk_alg/1>,
          type: :exrop,
          uniform: #Function<1.53802439/1 in :rand.mk_alg/1>,
          uniform_n: #Function<2.53802439/2 in :rand.mk_alg/1>,
          weak_low_bits: 1
        }
      }


  """
  def metadata(name \\ __MODULE__)
  @spec metadata(atom())::map()
  def metadata(name)do
    GenServer.call(name,:metadata)
  end

  @doc """
  Get the r-tree representation

  Returns `map()`

  ## Examples

      iex> Drtree.metadata(Peter)

      %{
        43143342109176739 => {["Parker", "Griffin"], nil, [{0, 11}, {0, 11}]},
        :root => 43143342109176739,
        :ticket => [19125803434255161 | 82545666616502197],
        "Griffin" => {:leaf, 43143342109176739, [{0, 1}, {0, 1}]},
        "Parker" => {:leaf, 43143342109176739, [{10, 11}, {10, 11}]}
      }


  """
  def tree(name \\ __MODULE__)
  @spec tree(atom())::map()
  def tree(name)do
    GenServer.call(name,:tree)
  end

  def merge_diffs(_a,name \\ __MODULE__)
  @doc false
  def merge_diffs(diffs,name)do
    send(name,{:merge_diff,diffs})
  end

  defp is_distributed?(state)do
    state.metadata[:params][:mode] == :distributed
  end

  defp constraints()do
    %{
      width: fn v -> v > 0 end,
      type: fn v -> v in (@opt_values |> Map.get(:type)) end,
      mode: fn v -> v in (@opt_values |> Map.get(:mode)) end,
      verbose: fn v -> is_boolean(v) end,
      seed: fn v -> is_integer(v) end
    }
  end

  defp filter_conf(opts)do
    new_opts = if opts[:mode] == :distributed, do: Map.put(opts,:type,MerkleMap), else: opts
    good_keys = new_opts |> Map.keys |> Enum.filter(fn k -> constraints() |> Map.has_key?(k) and constraints()[k].(new_opts[k]) end)
    good_keys |> Enum.reduce(@defopts, fn k,acc ->
      acc |> Map.put(k,new_opts[k])
    end)
  end

  defp get_rbundle(state)do
    meta = state.metadata
    params = meta.params
    %{
      tree: state.tree,
      width: params[:width],
      verbose: params[:verbose],
      type: params[:type],
      seeding: meta[:seeding]
    }
  end

  @doc false
  def start_link(opts)do
    name = if opts[:name], do: opts[:name], else: __MODULE__
    GenServer.start_link(__MODULE__,opts, name: name)
  end

  @impl true
  def init(opts)do
    conf = filter_conf(opts[:conf])
    {t,meta} = ElixirRtree.new(conf)
    listeners = Node.list
    t = if %{metadata: meta} |> is_distributed? do
      DeltaCrdt.set_neighbours(opts[:crdt],Enum.map(Node.list, fn x -> {opts[:crdt],x} end))
      :timer.sleep(10)
      crdt_value = DeltaCrdt.read(opts[:crdt])
      :net_kernel.monitor_nodes(true, node_type: :visible)
      if crdt_value != %{}, do: reconstruct_from_crdt(crdt_value,t), else: t
    else
      t
    end

    {:ok, %__MODULE__{metadata: meta, tree: t, listeners: listeners, crdt: opts[:crdt]}}
  end

  @impl true
  def handle_call({:new,config},_from,state)do
    conf = config |> filter_conf
    {t,meta} = ElixirRtree.new(conf)
    {:reply, {:ok,t} , %__MODULE__{state | metadata: meta, tree: t}}
  end

  @impl true
  def handle_call({:insert,leaf},_from,state)do
    r = {_atom,t} = case state.tree do
      nil -> {:badtree,state.tree}
      _ -> {:ok,get_rbundle(state) |> rinsert(leaf)}
    end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree,t)
      sync_crdt(diffs,state.crdt)
    end

    {:reply, r , %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:bulk_insert,leafs},_from,state)do
    r = {_atom,t} = case state.tree do
      nil -> {:badtree,state.tree}
      _ ->
        final_rbundle = leafs |> Enum.reduce(get_rbundle(state), fn l,acc ->
          %{acc | tree: acc |> rinsert(l)}
        end)
        {:ok,final_rbundle.tree}
    end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree,t)
      sync_crdt(diffs,state.crdt)
    end

    {:reply, r , %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:query,box},_from,state)do
    r = {_atom,_t} = case state.tree do
      nil -> {:badtree, state.tree}
      _ -> {:ok, get_rbundle(state) |> bquery(box)}
    end
    {:reply, r , state}
  end

  @impl true
  def handle_call({:query_depth,{box,depth}},_from,state)do
    r = {_atom,_t} = case state.tree do
      nil -> {:badtree,state.tree}
      _ -> {:ok,get_rbundle(state) |> bquery(box,depth)}
    end
    {:reply, r , state}
  end

  @impl true
  def handle_call({:delete,id},_from,state)do
    r = {_atom,t} = case state.tree do
      nil -> {:badtree,state.tree}
      _ -> {:ok,get_rbundle(state) |> rdelete(id)}
    end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree,t)
      sync_crdt(diffs,state.crdt)
    end

    {:reply, r , %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:bulk_delete,ids},_from,state)do
    r = {_atom,t} = case state.tree do
      nil -> {:badtree,state.tree}
      _ ->
        final_rbundle = ids |> Enum.reduce(get_rbundle(state), fn id,acc ->
          %{acc | tree: acc |> rdelete(id)}
        end)
        {:ok,final_rbundle.tree}
    end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree,t)
      sync_crdt(diffs,state.crdt)
    end

    {:reply, r , %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:update,{id,update}},_from,state)do
    r = {_atom,t} = case state.tree do
      nil -> {:badtree,state.tree}
      _ -> {:ok,get_rbundle(state) |> rupdate_leaf(id,update)}
    end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree,t)
      sync_crdt(diffs,state.crdt)
    end

    {:reply, r , %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:bulk_update,updates},_from,state)do
    r = {_atom,t} = case state.tree do
      nil -> {:badtree,state.tree}
      _ ->
        final_rbundle = updates |> Enum.reduce(get_rbundle(state), fn {id,update} = _u,acc ->
          %{acc | tree: acc |> rupdate_leaf(id,update)}
        end)
        {:ok,final_rbundle.tree}
    end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree,t)
      sync_crdt(diffs,state.crdt)
    end

    {:reply, r , %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call(:metadata,_from,state)do
    {:reply, state.metadata , state}
  end

  @impl true
  def handle_call(:tree,_from,state)do
    {:reply, state.tree , state}
  end

  # Distributed things

  @impl true
  def handle_info({:merge_diff,diff},state)do
   new_tree = diff |> Enum.reduce(state.tree, fn x,acc ->
      case x do
        {:add,k,v} -> acc |> MerkleMap.put(k,v)
        {:remove,k} -> acc |> MerkleMap.delete(k)
      end
    end)

    {:noreply , %__MODULE__{state | tree: new_tree}}
  end

  def handle_info({:nodeup, _node, _opts}, state) do
    DeltaCrdt.set_neighbours(state.crdt,Enum.map(Node.list, fn x -> {state.crdt,x} end))
    {:noreply, %__MODULE__{state | listeners: Node.list}}
  end

  def handle_info({:nodedown, _node, _opts}, state) do
    DeltaCrdt.set_neighbours(state.crdt,Enum.map(Node.list, fn x -> {state.crdt,x} end))
    {:noreply, %__MODULE__{state | listeners: Node.list}}
  end

  @doc false
  def sync_crdt(diffs,crdt)when length(diffs) > 0 do
    diffs |> Enum.each(fn {k,v} ->
      if v do
        DeltaCrdt.mutate(crdt, :add, [k, v])
      else
        DeltaCrdt.mutate(crdt, :remove, [k])
      end
    end)
  end

  @doc false
  def sync_crdt(_diffs,_crdt)do
  end

  @doc false
  def reconstruct_from_crdt(map,t)do
    map |> Enum.reduce(t,fn {x,y},acc ->
      acc |> MerkleMap.put(x,y)
    end)
  end

  @doc false
  def tree_diffs(old_tree,new_tree)do
    {:ok,keys} = MerkleMap.diff_keys(old_tree |> MerkleMap.update_hashes,new_tree |> MerkleMap.update_hashes)
    keys |> Enum.map(fn x -> {x,new_tree |> MerkleMap.get(x)} end)
  end

end
