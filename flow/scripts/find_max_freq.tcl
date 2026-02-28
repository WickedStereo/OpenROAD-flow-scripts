# Script to find maximum frequency for a design
source $::env(SCRIPTS_DIR)/load.tcl
load_design 1_synth.v 1_synth.sdc

puts "\n=========================================================================="
puts "Maximum Frequency Analysis"
puts "==========================================================================\n"

# Get the critical path
set critical_paths [find_timing_paths -sort_by_slack -max_paths 5]

if {[llength $critical_paths] > 0} {
    set worst_path [lindex $critical_paths 0]
    set path_delay [sta::format_time [[$worst_path path] arrival] 4]
    set path_slack [sta::format_time [[$worst_path path] slack] 4]
    set setup_time 0.0
    
    # Try to get setup time from the path
    set path_obj [$worst_path path]
    if {$path_obj != ""} {
        set checks [$worst_path checks]
        if {[llength $checks] > 0} {
            set check [lindex $checks 0]
            set setup_time [sta::format_time [$check setup_time] 4]
        }
    }
    
    # Get current clock period
    set clocks [all_clocks]
    if {[llength $clocks] > 0} {
        set clk [lindex $clocks 0]
        set current_period [sta::format_time [$clk period] 4]
        
        puts "Current Clock Period: ${current_period} ns"
        puts "Current Frequency: [format "%.2f" [expr 1000.0 / $current_period]] MHz\n"
        
        puts "Critical Path Analysis:"
        puts "  Path Delay: ${path_delay} ns"
        puts "  Setup Time: ${setup_time} ns"
        puts "  Current Slack: ${path_slack} ns"
        
        # Calculate minimum period (path delay + setup time)
        set min_period [expr $path_delay + $setup_time]
        set max_freq_ideal [expr 1000.0 / $min_period]
        
        puts "\nTheoretical Maximum (ideal clocks, no margin):"
        puts "  Minimum Period: [format "%.3f" $min_period] ns"
        puts "  Maximum Frequency: [format "%.2f" $max_freq_ideal] MHz"
        
        # Conservative estimate with margins
        # Add 10% for clock uncertainty/skew and process variations
        set margin_percent 10.0
        set min_period_with_margin [expr $min_period * (1.0 + $margin_percent / 100.0)]
        set max_freq_conservative [expr 1000.0 / $min_period_with_margin]
        
        puts "\nConservative Estimate (with ${margin_percent}% margin):"
        puts "  Minimum Period: [format "%.3f" $min_period_with_margin] ns"
        puts "  Maximum Frequency: [format "%.2f" $max_freq_conservative] MHz"
        
        # Check multiple paths to see if others might become critical
        puts "\nTop 5 Critical Paths:"
        set path_num 1
        foreach path $critical_paths {
            set delay [sta::format_time [[$path path] arrival] 4]
            set slack [sta::format_time [[$path path] slack] 4]
            set startpoint [[$path path] startpoint]
            set endpoint [[$path path] endpoint]
            puts "  Path $path_num: Delay=${delay} ns, Slack=${slack} ns"
            puts "    Start: [$startpoint name]"
            puts "    End:   [$endpoint name]"
            incr path_num
        }
        
        puts "\n=========================================================================="
        puts "Recommendation:"
        puts "=========================================================================="
        puts "Based on critical path analysis, you can safely target:"
        puts "  Period: [format "%.2f" $min_period_with_margin] ns"
        puts "  Frequency: [format "%.1f" $max_freq_conservative] MHz"
        puts "\nNote: This assumes ideal clock distribution. After place & route,"
        puts "      clock skew and routing delays will reduce the maximum frequency."
        puts "      Re-run timing analysis after each stage (place, cts, route)."
    }
} else {
    puts "No timing paths found!"
}

