import distributed_parent
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import parent

pub fn main() {
  let args = get_plain_args()

  case args {
    // Distributed: gleam run -- --distributed <n> <k> <local_node> <remote_nodes...>
    ["--distributed", n_str, k_str, local_node, ..remote_nodes] -> {
      run_distributed_mode(n_str, k_str, local_node, remote_nodes)
    }
    // Local: gleam run -- <n> <k>
    [n_str, k_str] -> {
      run_local_mode(n_str, k_str)
    }
    // Invalid args
    _ -> {
      Nil
    }
  }
}

fn run_distributed_mode(
  n_str: String,
  k_str: String,
  local_node: String,
  remote_nodes: List(String),
) {
  let assert Ok(n) = int.parse(n_str)
  let assert Ok(k) = int.parse(k_str)

  let config =
    distributed_parent.DistributedConfig(
      local_node_name: local_node,
      remote_nodes: remote_nodes,
      workers_per_node: 2,
    )

  io.println("Starting distributed computation...")
  io.println("Local node: " <> local_node)
  io.println("Remote nodes: " <> string.join(remote_nodes, ", "))

  // Start timing
  let start_real_time = get_precise_time()
  let start_cpu_time = get_cpu_time()

  let #(results, actual_workers, actual_nodes) =
    distributed_parent.find_sequences_multi_node_with_stats(k, n, config)

  // End timing
  let end_real_time = get_precise_time()
  let end_cpu_time = get_cpu_time()

  let real_duration = end_real_time - start_real_time
  let cpu_duration = end_cpu_time - start_cpu_time

  // CPU/Real ratio
  let cpu_real_ratio = case real_duration {
    0 -> 0.0
    _ -> int.to_float(cpu_duration) /. int.to_float(real_duration)
  }

  // Display solutions
  results
  |> list.sort(int.compare)
  |> list.each(fn(start) { io.println(int.to_string(start)) })

  // Timing stats
  io.println("")
  io.println("Real time: " <> int.to_string(real_duration) <> " ms")
  io.println("CPU time: " <> int.to_string(cpu_duration) <> " ms")
  io.println("CPU/Real ratio: " <> float.to_string(cpu_real_ratio))
  io.println("Total workers: " <> int.to_string(actual_workers))
  io.println("Nodes used: " <> int.to_string(actual_nodes))
}

fn run_local_mode(n_str: String, k_str: String) {
  let assert Ok(n) = int.parse(n_str)
  let assert Ok(k) = int.parse(k_str)

  let num_workers = 2

  // Start timing
  let start_real_time = get_precise_time()
  let start_cpu_time = get_cpu_time()

  let results = parent.find_sequences_distributed(k, n, num_workers)

  // End timing
  let end_real_time = get_precise_time()
  let end_cpu_time = get_cpu_time()

  let real_duration = end_real_time - start_real_time
  let cpu_duration = end_cpu_time - start_cpu_time

  // CPU/Real ratio
  let cpu_real_ratio = case real_duration {
    0 -> 0.0
    _ -> int.to_float(cpu_duration) /. int.to_float(real_duration)
  }

  // Display solutions
  results
  |> list.sort(int.compare)
  |> list.each(fn(start) { io.println(int.to_string(start)) })

  // Timing stats
  io.println("")
  io.println("Real time: " <> int.to_string(real_duration) <> " ms")
  io.println("CPU time: " <> int.to_string(cpu_duration) <> " ms")
  io.println("CPU/Real ratio: " <> float.to_string(cpu_real_ratio))
  io.println("Workers: " <> int.to_string(num_workers))
}

// Get command line args
@external(erlang, "ffi", "get_plain_arguments")
fn get_plain_args() -> List(String)

// Get process stats
@external(erlang, "ffi", "get_runtime")
fn get_runtime_stats() -> #(Int, Int)

// Get precise time in ms
@external(erlang, "ffi", "get_real_time")
fn get_precise_time() -> Int

fn get_cpu_time() -> Int {
  let #(runtime, _) = get_runtime_stats()
  runtime
}
