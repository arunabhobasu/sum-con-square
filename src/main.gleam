import gleam/float
import gleam/int
import gleam/io
import gleam/list
import parent

pub fn main() {
  // input command line arguments
  let assert [n_str, k_str] = get_plain_args()
  let assert Ok(n) = int.parse(n_str)
  let assert Ok(k) = int.parse(k_str)

  // SET NUMBER OF WORKERS HERE
  let num_workers = 8

  // start and stop timers
  let start_real_time = get_precise_time()
  let start_cpu_time = get_cpu_time()

  let results = parent.find_sequences_distributed(k, n, num_workers)

  let end_real_time = get_precise_time()
  let end_cpu_time = get_cpu_time()

  // Calculate durations and ratio 
  let real_duration = end_real_time - start_real_time
  let cpu_duration = end_cpu_time - start_cpu_time

  let cpu_real_ratio = case real_duration {
    0 -> 0.0
    _ -> int.to_float(cpu_duration) /. int.to_float(real_duration)
  }

  // Output results
  results
  |> list.sort(int.compare)
  |> list.each(fn(start) { io.println(int.to_string(start)) })

  io.println("")
  io.println("Real time: " <> int.to_string(real_duration) <> " ms")
  io.println("CPU time: " <> int.to_string(cpu_duration) <> " ms")
  io.println("CPU/Real ratio: " <> float.to_string(cpu_real_ratio))
  io.println("Workers: " <> int.to_string(num_workers))
}

// External functions
@external(erlang, "ffi", "get_plain_arguments")
fn get_plain_args() -> List(String)

@external(erlang, "ffi", "get_runtime")
fn get_runtime_stats() -> #(Int, Int)

@external(erlang, "ffi", "get_real_time")
fn get_precise_time() -> Int

fn get_cpu_time() -> Int {
  let #(runtime, _) = get_runtime_stats()
  runtime
}
