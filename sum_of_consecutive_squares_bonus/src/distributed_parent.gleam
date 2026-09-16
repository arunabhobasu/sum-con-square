import child
import distributed_worker
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/string

// FFI for distributed operations
@external(erlang, "distributed_ffi", "start_distribution")
fn start_distribution(node_name: String) -> Result(String, String)

@external(erlang, "distributed_ffi", "connect_node")
fn connect_node(node_name: String) -> Result(String, String)

@external(erlang, "distributed_ffi", "spawn_remote")
fn spawn_remote(
  node_name: String,
  module: String,
  function: String,
) -> Result(
  process.Subject(distributed_worker.DistributedWorkerMessage),
  String,
)

@external(erlang, "distributed_ffi", "get_hostname")
fn get_hostname() -> Result(String, String)

// Distributed execution config
pub type DistributedConfig {
  DistributedConfig(
    local_node_name: String,
    remote_nodes: List(String),
    workers_per_node: Int,
  )
}

// Distribute work across nodes with stats
pub fn distribute_work_distributed_with_stats(
  k: Int,
  max_start: Int,
  config: DistributedConfig,
) -> #(List(Int), Int, Int) {
  // Start distributed mode
  case start_distribution(config.local_node_name) {
    Ok(_) -> {
      // Connect to nodes
      let connected_nodes = connect_to_nodes(config.remote_nodes)

      // Fall back to local if no remote nodes
      case connected_nodes {
        [] -> {
          let results =
            distribute_work_local(k, max_start, config.workers_per_node)
          #(results, config.workers_per_node, 1)
        }
        _ -> {
          let all_nodes = [config.local_node_name, ..connected_nodes]
          let total_workers = list.length(all_nodes) * config.workers_per_node
          let total_nodes = list.length(all_nodes)
          let results =
            distribute_across_nodes(
              k,
              max_start,
              total_workers,
              all_nodes,
              config.workers_per_node,
            )
          #(results, total_workers, total_nodes)
        }
      }
    }
    Error(_) -> {
      // Fallback to local
      let results = distribute_work_local(k, max_start, config.workers_per_node)
      #(results, config.workers_per_node, 1)
    }
  }
}

// Distribute work across nodes
pub fn distribute_work_distributed(
  k: Int,
  max_start: Int,
  config: DistributedConfig,
) -> List(Int) {
  let #(results, _, _) =
    distribute_work_distributed_with_stats(k, max_start, config)
  results
}

// Connect to nodes
fn connect_to_nodes(nodes: List(String)) -> List(String) {
  list.fold(nodes, [], fn(connected, node) {
    case connect_node(node) {
      Ok(_) -> {
        // Connection successful
        case get_hostname() {
          Ok(_) -> Nil
          Error(_) -> Nil
        }
        [node, ..connected]
      }
      Error(_) -> {
        // Connection failed
        case get_hostname() {
          Ok(_) -> Nil
          Error(_) -> Nil
        }
        connected
      }
    }
  })
}

// Get node at index
fn get_node_at_index(nodes: List(String), index: Int) -> Result(String, Nil) {
  case nodes {
    [] -> Error(Nil)
    [first, ..rest] -> {
      case index {
        0 -> Ok(first)
        _ -> get_node_at_index(rest, index - 1)
      }
    }
  }
}

// Distribute across nodes
fn distribute_across_nodes(
  k: Int,
  max_start: Int,
  total_workers: Int,
  nodes: List(String),
  _workers_per_node: Int,
) -> List(Int) {
  let range_size = int.max(1, max_start / total_workers)
  let worker_ranges = create_ranges(1, max_start, range_size, [])

  // Subject for results
  let result_subject = process.new_subject()

  // Spawn workers
  let worker_actors =
    spawn_distributed_workers(worker_ranges, nodes, k, result_subject)

  // Count workers
  let successful_workers = list.length(worker_actors)

  // Collect results
  collect_distributed_results(result_subject, successful_workers, [])
}

// Spawn workers across nodes
fn spawn_distributed_workers(
  ranges: List(#(Int, Int)),
  nodes: List(String),
  k: Int,
  result_subject: process.Subject(distributed_worker.DistributedResult),
) -> List(process.Subject(distributed_worker.DistributedWorkerMessage)) {
  let node_count = list.length(nodes)

  list.index_fold(ranges, [], fn(workers, range, index) {
    let #(start, end) = range
    let node_index = index % node_count

    case get_node_at_index(nodes, node_index) {
      Ok(node_name) -> {
        case spawn_worker_on_node(node_name, start, end, k, result_subject) {
          Ok(worker) -> [worker, ..workers]
          Error(_) -> workers
        }
      }
      Error(_) -> workers
    }
  })
}

// Spawn worker on node
fn spawn_worker_on_node(
  node_name: String,
  start: Int,
  end: Int,
  k: Int,
  result_subject: process.Subject(distributed_worker.DistributedResult),
) -> Result(
  process.Subject(distributed_worker.DistributedWorkerMessage),
  String,
) {
  case is_local_node(node_name) {
    True -> {
      // Spawn locally
      case distributed_worker.start_distributed_worker() {
        Ok(actor_started) -> {
          let worker_subject = actor_started.data
          process.send(
            worker_subject,
            distributed_worker.ComputeRange(start, end, k, result_subject),
          )
          Ok(worker_subject)
        }
        Error(_) -> Error("Failed to start local worker")
      }
    }
    False -> {
      // Spawn remotely
      case
        spawn_remote(node_name, "distributed_worker", "remote_worker_entry")
      {
        Ok(worker_subject) -> {
          process.send(
            worker_subject,
            distributed_worker.ComputeRange(start, end, k, result_subject),
          )
          Ok(worker_subject)
        }
        Error(err) -> Error("Failed to spawn remote worker: " <> err)
      }
    }
  }
}

// Check if node is local
fn is_local_node(node_name: String) -> Bool {
  case get_hostname() {
    Ok(hostname) -> string.contains(node_name, hostname)
    Error(_) ->
      string.contains(node_name, "localhost")
      || string.contains(node_name, "127.0.0.1")
  }
}

// Collect results
fn collect_distributed_results(
  subject: process.Subject(distributed_worker.DistributedResult),
  remaining: Int,
  acc: List(List(Int)),
) -> List(Int) {
  case remaining {
    0 ->
      list.fold(acc, [], fn(combined, worker_results) {
        list.append(combined, worker_results)
      })
    _ -> {
      case process.receive(subject, 60_000) {
        // 60s timeout
        Ok(distributed_worker.ComputationResult(results, _node)) ->
          collect_distributed_results(subject, remaining - 1, [results, ..acc])
        Error(_) ->
          collect_distributed_results(subject, remaining - 1, [[], ..acc])
        // Timeout
      }
    }
  }
}

// Local execution fallback
fn distribute_work_local(k: Int, max_start: Int, num_workers: Int) -> List(Int) {
  let range_size = int.max(1, max_start / num_workers)
  let worker_ranges = create_ranges(1, max_start, range_size, [])

  // Subject for results
  let result_subject = process.new_subject()

  // Start workers and send work
  let worker_actors =
    list.map(worker_ranges, fn(range) {
      let #(start, end) = range
      case child.start_worker() {
        Ok(actor_result) -> {
          let worker_subject = actor_result.data
          // Send task to worker
          process.send(
            worker_subject,
            child.ComputeRange(start, end, k, result_subject),
          )
          Ok(worker_subject)
        }
        Error(err) -> Error(err)
      }
    })

  // Count workers
  let successful_workers =
    list.fold(worker_actors, 0, fn(count, result) {
      case result {
        Ok(_) -> count + 1
        Error(_) -> count
      }
    })

  // Collect results from workers
  collect_local_results(result_subject, successful_workers, [])
}

// Collect local results
fn collect_local_results(
  subject: process.Subject(List(Int)),
  remaining: Int,
  acc: List(List(Int)),
) -> List(Int) {
  case remaining {
    0 ->
      list.fold(acc, [], fn(combined, worker_results) {
        list.append(combined, worker_results)
      })
    _ -> {
      case process.receive(subject, 60_000) {
        // 60s timeout
        Ok(results) ->
          collect_local_results(subject, remaining - 1, [results, ..acc])
        Error(_) -> collect_local_results(subject, remaining - 1, [[], ..acc])
        // Timeout
      }
    }
  }
}

// Create worker ranges
fn create_ranges(
  start: Int,
  max_end: Int,
  range_size: Int,
  acc: List(#(Int, Int)),
) -> List(#(Int, Int)) {
  case start > max_end {
    True -> list.reverse(acc)
    False -> {
      let end = int.min(start + range_size - 1, max_end)
      let new_range = #(start, end)
      create_ranges(end + 1, max_end, range_size, [new_range, ..acc])
    }
  }
}

// Local distribution (compatibility)
pub fn distribute_work(k: Int, max_start: Int, num_workers: Int) -> List(Int) {
  distribute_work_local(k, max_start, num_workers)
}

// Find sequences distributed
pub fn find_sequences_distributed(
  k: Int,
  max_start: Int,
  num_workers: Int,
) -> List(Int) {
  distribute_work(k, max_start, num_workers)
}

// Find sequences multi-node
pub fn find_sequences_multi_node(
  k: Int,
  max_start: Int,
  config: DistributedConfig,
) -> List(Int) {
  let #(results, _, _) =
    find_sequences_multi_node_with_stats(k, max_start, config)
  results
}

// Find sequences with stats
pub fn find_sequences_multi_node_with_stats(
  k: Int,
  max_start: Int,
  config: DistributedConfig,
) -> #(List(Int), Int, Int) {
  case distribute_work_distributed_with_stats(k, max_start, config) {
    #(results, workers, nodes) -> #(results, workers, nodes)
  }
}
