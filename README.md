# tsc_cpu

CPU implemented using TSC ISA for SNU ECE430.322 Computer organization

1. single_cycle cpu only have several instructions.
   Others implement all insturctions in TSC ISA.

2. multi_cycle cpu is implementation with all TSC instructions. From this implementation, test bench is same

3. pipeline is pipelined cpu implementation with branch predictor and data forwarding

4. cache_baseline is pipelined cpu with memory latency model, but without cache.

5. cache is pipelined cpu with cache

6. DMA is added to cache and pipelined cpu.
   There are two files of DMA module, which are DMA.v and DMA_cycle_stealing.v
   
   Cycle stealing is implemented in DMA_cycle_stealing.v

## For more information check the reports
- [single -cycle](https://github.com/jaewonlee16/tsc_cpu/blob/master/single_cycle/Lab04%20report.pdf)
- [multi-cycle](https://github.com/jaewonlee16/tsc_cpu/blob/master/multi_cycle/lab05%20report.pdf)
- [pipeline](https://github.com/jaewonlee16/tsc_cpu/blob/master/pipeline/Lab06%20report.pdf)
- [cache](https://github.com/jaewonlee16/tsc_cpu/blob/master/cache/lab07%20report.pdf)
- [DMA](https://github.com/jaewonlee16/tsc_cpu/blob/master/DMA/lab08%20report.pdf)
