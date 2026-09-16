import gleam/float
import gleam/int

/// Sum of squares of k consecutive integers from n
pub fn sum_of_consecutive_squares(start: Int, count: Int) -> Int {
  case count {
    0 -> 0
    1 -> start * start
    _ -> {
      // k*n² + k*(k-1)*n + k*(k-1)*(2*k-1)/6
      let n = start
      let k = count
      let k_minus_1 = k - 1
      let term1 = k * n * n
      let term2 = k * k_minus_1 * n
      let term3 = k * k_minus_1 * { 2 * k - 1 } / 6
      term1 + term2 + term3
    }
  }
}

/// Check if number is perfect square
pub fn is_perfect_square(n: Int) -> Bool {
  case n {
    n if n < 0 -> False
    0 -> True
    1 -> True
    _ -> {
      case int.to_float(n) |> float.square_root {
        Ok(sqrt_float) -> {
          let sqrt_int = float.truncate(sqrt_float)
          sqrt_int * sqrt_int == n
        }
        Error(_) -> False
      }
    }
  }
}

/// Find starting numbers for valid sequences
pub fn find_valid_sequences(k: Int, max_start_number: Int) -> List(Int) {
  find_valid_sequences_helper(1, k, max_start_number, [])
}

fn find_valid_sequences_helper(
  start: Int,
  k: Int,
  max_start_number: Int,
  acc: List(Int),
) -> List(Int) {
  case start > max_start_number {
    True -> acc
    False -> {
      let sum = sum_of_consecutive_squares(start, k)
      let new_acc = case is_perfect_square(sum) {
        True -> [start, ..acc]
        False -> acc
      }
      find_valid_sequences_helper(start + 1, k, max_start_number, new_acc)
    }
  }
}
