#!/usr/bin/env python3
"""
Validation Results Caching Module

This module provides caching functionality for validation results to speed up
repeated validation runs when files haven't changed.

Usage:
    from validation_cache import ValidationCache
    
    cache = ValidationCache()
    
    # Try to load cached results
    cached = cache.load_cached_results(file_path)
    if cached:
        return cached
    
    # Run validation...
    results = validate_file(file_path)
    
    # Save to cache
    cache.save_cached_results(file_path, results)
"""

import os
import hashlib
import pickle
import json
from pathlib import Path
from typing import Any, Optional, Dict
from datetime import datetime, timedelta


class ValidationCache:
    """Cache for validation results with file hash-based invalidation."""
    
    def __init__(self, cache_dir: Optional[str] = None, max_age_days: int = 7):
        """Initialize validation cache.
        
        Args:
            cache_dir: Directory to store cache files. If None, uses .validation_cache
                      in the same directory as the validated files.
            max_age_days: Maximum age of cache entries in days before auto-invalidation.
        """
        self.cache_dir = cache_dir
        self.max_age_days = max_age_days
        self._cache_stats = {
            'hits': 0,
            'misses': 0,
            'saves': 0,
            'errors': 0
        }
    
    def _get_cache_dir(self, file_path: str) -> Path:
        """Get cache directory for a file."""
        if self.cache_dir:
            return Path(self.cache_dir)
        
        # Use a .validation_cache directory next to the validated file
        file_parent = Path(file_path).parent
        cache_dir = file_parent / '.validation_cache'
        cache_dir.mkdir(exist_ok=True)
        return cache_dir
    
    def _get_file_hash(self, file_path: str) -> str:
        """Calculate SHA256 hash of file content.
        
        Args:
            file_path: Path to file to hash
            
        Returns:
            Hexadecimal hash string
        """
        sha256 = hashlib.sha256()
        try:
            with open(file_path, 'rb') as f:
                # Read in chunks to handle large files efficiently
                for chunk in iter(lambda: f.read(8192), b''):
                    sha256.update(chunk)
            return sha256.hexdigest()
        except Exception:
            # If we can't hash the file, return empty string to skip caching
            return ""
    
    def _get_cache_path(self, file_path: str) -> Path:
        """Get cache file path for a validation target.
        
        Args:
            file_path: Path to file being validated
            
        Returns:
            Path to cache file
        """
        cache_dir = self._get_cache_dir(file_path)
        file_name = Path(file_path).name
        cache_name = f"{file_name}.cache"
        return cache_dir / cache_name
    
    def _is_cache_valid(self, cache_data: Dict[str, Any], file_hash: str) -> bool:
        """Check if cached data is still valid.
        
        Args:
            cache_data: Cached data dictionary
            file_hash: Current file hash
            
        Returns:
            True if cache is valid, False otherwise
        """
        # Check if hash matches
        if cache_data.get('hash') != file_hash:
            return False
        
        # Check if cache is too old
        if 'timestamp' in cache_data:
            try:
                cache_time = datetime.fromisoformat(cache_data['timestamp'])
                age = datetime.now() - cache_time
                if age > timedelta(days=self.max_age_days):
                    return False
            except Exception:
                return False
        
        return True
    
    def load_cached_results(self, file_path: str) -> Optional[Any]:
        """Load validation results from cache if available and valid.
        
        Args:
            file_path: Path to file being validated
            
        Returns:
            Cached validation results if valid, None otherwise
        """
        cache_path = self._get_cache_path(file_path)
        
        if not cache_path.exists():
            self._cache_stats['misses'] += 1
            return None
        
        try:
            # Get current file hash
            file_hash = self._get_file_hash(file_path)
            if not file_hash:
                self._cache_stats['errors'] += 1
                return None
            
            # Load cache file
            with open(cache_path, 'rb') as f:
                cache_data = pickle.load(f)
            
            # Validate cache
            if not self._is_cache_valid(cache_data, file_hash):
                self._cache_stats['misses'] += 1
                return None
            
            self._cache_stats['hits'] += 1
            return cache_data.get('results')
            
        except Exception as e:
            # On any error, treat as cache miss
            self._cache_stats['errors'] += 1
            return None
    
    def save_cached_results(self, file_path: str, results: Any) -> bool:
        """Save validation results to cache.
        
        Args:
            file_path: Path to file being validated
            results: Validation results to cache
            
        Returns:
            True if saved successfully, False otherwise
        """
        try:
            cache_path = self._get_cache_path(file_path)
            
            # Get file hash
            file_hash = self._get_file_hash(file_path)
            if not file_hash:
                return False
            
            # Prepare cache data
            cache_data = {
                'hash': file_hash,
                'timestamp': datetime.now().isoformat(),
                'results': results,
                'file_path': str(file_path)
            }
            
            # Save to cache
            with open(cache_path, 'wb') as f:
                pickle.dump(cache_data, f, protocol=pickle.HIGHEST_PROTOCOL)
            
            self._cache_stats['saves'] += 1
            return True
            
        except Exception as e:
            self._cache_stats['errors'] += 1
            return False
    
    def clear_cache(self, file_path: Optional[str] = None) -> int:
        """Clear cache files.
        
        Args:
            file_path: If provided, clear cache for this file only.
                      If None, clear all cache files in cache directory.
                      
        Returns:
            Number of cache files deleted
        """
        deleted = 0
        
        try:
            if file_path:
                # Clear specific file cache
                cache_path = self._get_cache_path(file_path)
                if cache_path.exists():
                    cache_path.unlink()
                    deleted = 1
            else:
                # Clear all caches in cache directory
                if self.cache_dir:
                    cache_dir = Path(self.cache_dir)
                    if cache_dir.exists():
                        for cache_file in cache_dir.glob("*.cache"):
                            cache_file.unlink()
                            deleted += 1
        except Exception:
            pass
        
        return deleted
    
    def get_stats(self) -> Dict[str, int]:
        """Get cache statistics.
        
        Returns:
            Dictionary with cache hit/miss/save/error counts
        """
        stats = self._cache_stats.copy()
        
        # Calculate hit rate
        total_attempts = stats['hits'] + stats['misses']
        if total_attempts > 0:
            stats['hit_rate'] = stats['hits'] / total_attempts
        else:
            stats['hit_rate'] = 0.0
        
        return stats
    
    def print_stats(self):
        """Print cache statistics to stdout."""
        stats = self.get_stats()
        print("\n" + "="*70)
        print("CACHE STATISTICS")
        print("="*70)
        print(f"Cache Hits:    {stats['hits']}")
        print(f"Cache Misses:  {stats['misses']}")
        print(f"Cache Saves:   {stats['saves']}")
        print(f"Cache Errors:  {stats['errors']}")
        
        if stats['hits'] + stats['misses'] > 0:
            hit_rate_pct = stats['hit_rate'] * 100
            print(f"Hit Rate:      {hit_rate_pct:.1f}%")
            
            if hit_rate_pct > 80:
                print("Performance:   ⚡ EXCELLENT")
            elif hit_rate_pct > 50:
                print("Performance:   ✅ GOOD")
            else:
                print("Performance:   📊 MODERATE")
        print()


def main():
    """Demo/test the caching module."""
    import sys
    
    if len(sys.argv) < 2:
        print(__doc__)
        print("\nDemo Usage:")
        print("    python3 validation_cache.py <file_path>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    # Test cache operations
    cache = ValidationCache()
    
    print(f"Testing cache with: {file_path}")
    print()
    
    # Try to load from cache
    print("1. Attempting to load from cache...")
    cached = cache.load_cached_results(file_path)
    if cached:
        print("   ✅ Cache hit!")
        print(f"   Cached results: {cached}")
    else:
        print("   ❌ Cache miss")
    
    # Save to cache
    print("\n2. Saving test data to cache...")
    test_data = {
        'valid_count': 42,
        'errors': [],
        'timestamp': datetime.now().isoformat()
    }
    if cache.save_cached_results(file_path, test_data):
        print("   ✅ Saved successfully")
    else:
        print("   ❌ Save failed")
    
    # Try loading again
    print("\n3. Loading from cache again...")
    cached = cache.load_cached_results(file_path)
    if cached:
        print("   ✅ Cache hit!")
        print(f"   Cached results: {cached}")
    else:
        print("   ❌ Cache miss")
    
    # Print stats
    cache.print_stats()


if __name__ == "__main__":
    main()
