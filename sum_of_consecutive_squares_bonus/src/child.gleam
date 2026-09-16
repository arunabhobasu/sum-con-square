import computation
import gleam/erlang/process
import gleam/list
import gleam/otp/actor

// Worker message types
pub type WorkerMessage {
  ComputeRange(
    start: Int,
    end: Int,
    k: Int,
    reply_to: process.Subject(List(Int)),
  )
}

// Start worker actor
pub fn start_worker() -> Result(
  actor.Started(process.Subject(WorkerMessage)),
  actor.StartError,
) {
  actor.new([])
  |> actor.on_message(handle_message)
  |> actor.start
}

// Handle worker messages
fn handle_message(
  state: List(Int),
  message: WorkerMessage,
) -> actor.Next(List(Int), WorkerMessage) {
  case message {
    ComputeRange(start, end, k, reply_to) -> {
      let results = find_valid_in_range(start, end, k)
      process.send(reply_to, results)
      actor.continue(state)
    }
  }
}

// Process range of starting numbers
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
