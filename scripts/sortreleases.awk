#!/usr/bin/awk -f

# AWK script to sort the "fossil tag list" output
#  to select tags beginning with RELEASE- and output then in
#  version number order, latest version first.
# I know qawk has asort, but this script should work with very old macOS awk.
BEGIN { current_index = 1 }


/^RELEASE/ {
    sub("RELEASE-","",$1);
    original[current_index++] = $1;
    current_index++;
}

# when all records are processed
END {
    homebrew_asort(original, new);
    for( i in new) sizenew++;
    for(i = sizenew-1; i>0; i--){
        # Output in reverse order
        printf("%s\n", original[new[i]]);
    }

}

#################
function versionnumbercompare( v1, v2){
    split( v1, x1, /\./);
    split( v2, x2, /\./);
    # test major
    f=1;
    if( (0 + x1[f]) > (0 + x2[f])) return  1;
    if( (0 + x1[f]) < (0 + x2[f])) return -1;
    # major is the same, now test minor
    f=2
    if( (0 + x1[f]) > (0 + x2[f])) return  1;
    if( (0 + x1[f]) < (0 + x2[f])) return -1;
    # major and minor are the same, test patchlevel
    f=3;
    if( (0 + x1[f]) > (0 + x2[f])) return  1;
    if( (0 + x1[f]) < (0 + x2[f])) return -1;
    # versions are identical, return 0
    return 0;
}
#################

# See http://gotofritz.net/blog/geekery/a-selection-of-akw-scripts/
#
# kickstarts the sort process
# puts all the sorted keys into a separate array. if i
function homebrew_asort(original, processed) {
  # before we use the array we must be sure it is empty
  empty_array(processed)
  original_length = copy_and_count_array(original, processed)
  qsort(original, processed, 0, original_length)
  return original_length
}

# removes all values
function empty_array(A) {
  for (i in A)
    delete A[i]
}

# awk doesn't even have an array size function... you also have to roll out your own
function copy_and_count_array(original, processed) {
  for (key in original) {
      # awk doesn't seem to like array[0] -  so we start from 1
      size++;
      processed[size] = key
  }
  return size
}

# Adapted from a script from awk.info
# http://awk.info/?quicksort
function qsort(original, keys, left, right,   i, last) {
  if (left >= right)  return
  swap(keys, left, left + int( (right - left + 1) * rand() ) )
  last = left
  for (i = left+1; i <= right; i++)
      if (versionnumbercompare(original[keys[i]], original[keys[left]]) == -1)
      swap(keys, ++last, i)
  swap(keys, left, last)
  qsort(original, keys, left, last-1)
  qsort(original, keys, last+1, right)
}
function swap(A, i, j,   t) {
  t = A[i]; A[i] = A[j]; A[j] = t
}




