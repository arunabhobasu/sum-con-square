import child
import gleam/erlang/process
import gleam/int
import gleam/list

// distribute work among actors
pub fn distribute_work(k: Int, max_start: Int, num_workers: Int) -> List(Int) {
  let range_size = int.max(1, max_start / num_workers)
  let worker_ranges = create_ranges(1, max_start, range_size, [])

  // subject to collect results
  let result_subject = process.new_subject()

  // spawn actors and assign tasks
  let worker_actors =
    list.map(worker_ranges, fn(range) {
      let #(start, end) = range
      case child.start_worker() {
        Ok(actor_result) -> {
          let worker_subject = actor_result.data
          process.send(
            worker_subject,
            child.ComputeRange(start, end, k, result_subject),
          )
          Ok(worker_subject)
        }
        Error(err) -> Error(err)
      }
    })

  // count successfully spawned workers
  let successful_workers =
    list.fold(worker_actors, 0, fn(count, result) {
      case result {
        Ok(_) -> count + 1
        Error(_) -> count
      }
    })

  // collect actor results
  collect_actor_results(result_subject, successful_workers, [])
}

fn collect_actor_results(
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
        // wait 60 seconds for results or timeout
        Ok(results) ->
          collect_actor_results(subject, remaining - 1, [results, ..acc])
        Error(_) -> collect_actor_results(subject, remaining - 1, [[], ..acc])
      }
    }
  }
}

// create work unit ranges for each actor
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

// find all valid sequences
pub fn find_sequences_distributed(
  k: Int,
  max_start: Int,
  num_workers: Int,
) -> List(Int) {
  distribute_work(k, max_start, num_workers)
}
