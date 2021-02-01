    
.cc_top set_decoupler_r.func, set_decoupler_r
    .align 4
    .globl set_decoupler_r
    .globl set_decoupler_r.nstackwords
    .linkset set_decoupler_r.nstackwords, 0
set_decoupler_r:
    nop
    entsp 0
    stw r0, dp[decoupler_r]
    retsp 0
.cc_bottom set_decoupler_r.func

        
.cc_top set_decoupler_r2.func, set_decoupler_r2
    .align 4
    .globl set_decoupler_r2
    .globl set_decoupler_r2.nstackwords
    .linkset set_decoupler_r2.nstackwords, 0
set_decoupler_r2:
    nop
    entsp 0
    stw r0, dp[decoupler_r2]
    retsp 0
.cc_bottom set_decoupler_r2.func
