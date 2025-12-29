#!/usr/bin/env python3
"""
Performance Benchmark Suite for BG3 Validation Scripts

This script benchmarks the performance of validation scripts to track improvements.

Usage:
    python3 benchmark_validation.py <path_to_mod_directory>

Example:
    python3 benchmark_validation.py Public/EldertideArmament/
"""

import sys
import os
import time
import subprocess
from pathlib import Path
from typing import Dict, Tuple

# Module-level constants for better performance
_SUMMARY_KEYWORDS = ('VALIDATION SUMMARY', 'VALIDATION PASSED', 'VALIDATION FAILED')

def benchmark_command(command: list, description: str) -> Tuple[float, int]:
    """Run a command and measure its execution time.
    
    Returns:
        Tuple of (execution_time_seconds, exit_code)
    """
    print(f"\n{'='*70}")
    print(f"Benchmarking: {description}")
    print(f"{'='*70}")
    
    start_time = time.time()
    
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        end_time = time.time()
        execution_time = end_time - start_time
        
        # Print summary of output - optimized to avoid repeated string searches
        lines = result.stdout.split('\n')
        summary_started = False
        
        for line in lines:
            # Use any() with generator for early exit on first match (uses module-level constant)
            if not summary_started and any(keyword in line for keyword in _SUMMARY_KEYWORDS):
                summary_started = True
            if summary_started:
                print(line)
        
        print(f"\n⏱️  Execution Time: {execution_time:.3f} seconds")
        
        return execution_time, result.returncode
        
    except subprocess.TimeoutExpired:
        end_time = time.time()
        execution_time = end_time - start_time
        print(f"❌ Timeout after {execution_time:.3f} seconds")
        return execution_time, -1
    except Exception as e:
        end_time = time.time()
        execution_time = end_time - start_time
        print(f"❌ Error: {e}")
        return execution_time, -1

def run_benchmarks(mod_directory: str) -> Dict[str, float]:
    """Run all validation benchmarks.
    
    Returns:
        Dictionary mapping benchmark name to execution time
    """
    results = {}
    script_dir = Path(__file__).parent
    
    # Benchmark 1: Spell Validation
    spell_time, _ = benchmark_command(
        ["python3", str(script_dir / "validate_spells.py"), 
         f"{mod_directory}/Stats/Generated/Data/"],
        "Spell Validation"
    )
    results["spell_validation"] = spell_time
    
    # Benchmark 2: Item Validation
    item_time, _ = benchmark_command(
        ["python3", str(script_dir / "validate_items.py"),
         f"{mod_directory}/Stats/Generated/Data/"],
        "Item Validation"
    )
    results["item_validation"] = item_time
    
    # Benchmark 3: Reference Validation
    ref_time, _ = benchmark_command(
        ["python3", str(script_dir / "validate_references.py"),
         mod_directory],
        "Cross-Reference Validation"
    )
    results["reference_validation"] = ref_time
    
    return results

def print_summary(results: Dict[str, float]):
    """Print benchmark summary."""
    print(f"\n{'='*70}")
    print("BENCHMARK SUMMARY")
    print(f"{'='*70}")
    
    total_time = sum(results.values())
    
    for name, time_val in results.items():
        percentage = (time_val / total_time * 100) if total_time > 0 else 0
        print(f"  {name:30s}: {time_val:6.3f}s ({percentage:5.1f}%)")
    
    print(f"  {'-'*42}")
    print(f"  {'Total Time':30s}: {total_time:6.3f}s")
    print()
    
    # Performance ratings
    if total_time < 0.1:
        rating = "⚡ EXCELLENT - Lightning fast!"
    elif total_time < 0.5:
        rating = "✅ GOOD - Fast validation"
    elif total_time < 2.0:
        rating = "👍 ACCEPTABLE - Reasonable performance"
    else:
        rating = "⚠️  SLOW - Consider optimization"
    
    print(f"Performance Rating: {rating}")
    print()

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    mod_directory = sys.argv[1]
    
    if not os.path.exists(mod_directory):
        print(f"❌ Error: Path does not exist: {mod_directory}")
        sys.exit(1)
    
    print("="*70)
    print("BG3 Validation Performance Benchmark Suite")
    print("="*70)
    print(f"Target: {mod_directory}")
    print()
    
    results = run_benchmarks(mod_directory)
    print_summary(results)
    
    # Save results to file for tracking
    results_file = Path(__file__).parent / "benchmark_results.txt"
    with open(results_file, 'a') as f:
        import datetime
        timestamp = datetime.datetime.now().isoformat()
        f.write(f"\n{timestamp}\n")
        for name, time_val in results.items():
            f.write(f"  {name}: {time_val:.3f}s\n")
        f.write(f"  Total: {sum(results.values()):.3f}s\n")
    
    print(f"📊 Results appended to: {results_file}")

if __name__ == "__main__":
    main()
