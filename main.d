module main;

/* 
 * Performance comparison of various ordered data structures with log(n) insertion and removal times:
 * avl trees, skip lists (several variants) and B-trees.
 * 
 * Copyright (c) 2013 Sébastien KUNZ-JACQUES
 * 
 * This file is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * See <http://www.gnu.org/licenses/>. */

import avl;
import skipLists;
import coalescedSkipLists;
import skipListsWithArray;
import Btree; 

void main(string[] args)
{
  uint numElts = 1000000;
  // perform the same test on various data structures, here tested from slowest to fastest
  coalescedSkipListUnitTest(numElts);
  skipListUnitTest(numElts);
  avlTreeUnitTest2(numElts);
  skipListWithArraysUnitTest(numElts);
  btreeUnitTest(numElts);
}

