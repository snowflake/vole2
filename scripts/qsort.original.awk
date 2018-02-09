# This is the original text from
# http://gotofritz.net/blog/geekery/a-selection-of-akw-scripts/


# kickstarts the sort process
# puts all the sorted keys into a separate array. if i
function homebrew_asort(original, processed) {
  # before we use the array we must be sure it is empty
  empty_array(processed)
  original_length = copy_and_count_array(original, processed)
  qsort(original, processed, 0, original_length)
  return original_length
}

# removes al values
function empty_array(A) {
  for (i in A)
    delete A[i]
}

# awk doesn't even have an array size function... you also have to roll out your own
function copy_and_count_array(original, processed) {
  for (key in original) {
    # awk doesn't seem to like array[0] -  so we start from 1
    size++
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
    if (original[keys[i]] < original[keys[left]])
      swap(keys, ++last, i)
  swap(keys, left, last)
  qsort(original, keys, left, last-1)
  qsort(original, keys, last+1, right)
}
function swap(A, i, j,   t) {
  t = A[i]; A[i] = A[j]; A[j] = t
}

# same formatting function as before
function print_party_percentage(party_name, party_vote, total_vote) {
  printf "%5s: %4.1f%%\n", party_name, (100 * party_vote / total_vote)
}

# same main action as before
NR > 1 && NF  {
  total += $6
  party_totals[$NF] += $6
}

# when all records are processed
END {
  parties_count = homebrew_asort(party_totals, keys)
  for  (i = parties_count; i >= parties_count - 5; i--)
    print_party_percentage(keys[i], party_totals[keys[i]], total)
}
