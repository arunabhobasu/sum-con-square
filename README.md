# Project 1 of course COP 5615 : Distributed Operating Systems
## Sum of Consecutive Squares which is also a perfect square, calculated in distributed fashion using OTP actor model of Gleam

## To Run the program use the command :
gleam run <N> <k>


### Size of Work Unit that works best for me was 8 since I had 8 logical cores on my computer. I tried varying
the number of workers from 2, 4, 8 and 8 had the best performance



### Result of running N = 1000000, k = 4 :

PS C:\Users\Arunabho\Desktop\sum_of_consecutive_squares> gleam run 1000000 4
   Compiled in 0.04s
    Running main.main

Real time: 30 ms
CPU time: 141 ms
CPU/Real ratio: 4.7
Workers: 8



### The largest problem I could solve on my computer with a reasonable time frame (7 mins) was N = 10billion, k = 4

PS C:\Users\Arunabho\Desktop\sum_of_consecutive_squares> gleam run 10000000000 4
   Compiled in 0.05s
    Running main.main

Real time: 436324 ms
CPU time: 3300860 ms
CPU/Real ratio: 7.5651580018518345
Workers: 8



