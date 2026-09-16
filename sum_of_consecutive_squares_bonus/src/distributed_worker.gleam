import computation
import gleam/erlang/process
import gleam/list
import gleam/otp/actor

// Distributed worker message types
pub type DistributedWorkerMessage {
  ComputeRange(
    start: Int,
    end: Int,
    k: Int,
    reply_to: process.Subject(DistributedResult),
  )
  Shutdown
}

// Result with node info
pub type DistributedResult {
  ComputationResult(results: List(Int), node: String)
}

// FFI for distributed ops
@external(erlang, "distributed_ffi", "get_node_name")
fn get_node_name() -> String

// Start distributed worker
pub fn start_distributed_worker() -> Result(
  actor.Started(process.Subject(DistributedWorkerMessage)),
  actor.StartError,
) {
  actor.new([])
  |> actor.on_message(handle_distributed_message)
  |> actor.start
}

// Handle distributed messages
fn handle_distributed_message(
  state: List(Int),
  message: DistributedWorkerMessage,
) -> actor.Next(List(Int), DistributedWorkerMessage) {
  case message {
    ComputeRange(start, end, k, reply_to) -> {
      let results = find_valid_in_range(start, end, k)
      let node_name = get_node_name()
      let result = ComputationResult(results, node_name)
      process.send(reply_to, result)
      actor.continue(state)
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

// Process range
pub fn find_valid_in_range(start: Int, end: Int, k: Int) -> List(Int) {
  find_valid_in_range_helper(start, end, k, [])
}

fn find_valid_in_range_helper(
  current: Int,
  end: Int,
  k: Int,
  acc: List(Int),
) -> List(Int) {
  case current > end {
    True -> list.reverse(acc)
    False -> {
      let sum = computation.sum_of_consecutive_squares(current, k)
      let new_acc = case computation.is_perfect_square(sum) {
        True -> [current, ..acc]
        False -> acc
      }
      find_valid_in_range_helper(current + 1, end, k, new_acc)
    }
  }
}

// Remote spawn entry point
pub fn remote_worker_entry() -> process.Subject(DistributedWorkerMessage) {
  case start_distributed_worker() {
    Ok(actor_started) -> actor_started.data
    Error(_) -> {
      // Dummy subject
      process.new_subject()
    }
  }
}
