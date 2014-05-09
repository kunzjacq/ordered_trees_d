/* Interface for the various structures tested: avl, Btrees etc implement this interface 
 * Two functions are defined below to standardize tests on ordered structures. These functions are used for 
 * timing of insertions and removals.
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

module orderedSet;

import std.stdio;
import std.random;
import std.datetime;

interface OrderedSet(T)
{
  bool insert(T value);
  bool remove(T value);
  bool check();
  void setDebugFlag(bool);
}

/* Insert numElts chosen at random between 0 and numElts. With numElts large, there are redundancies with 
 * overwhelming probability. Track elements presence in a regular boolean array; check that an element is inserted 
 * exactly in the cases when it was not already present.
 * The self-consistency check method check() is optionally called after each insertion.
 */
void orderedSetInsertTest(OrderedSet!(uint) set, uint numElts, bool doCheck)
{
  uint [] values = new uint[numElts];
  bool [] state = new bool[numElts];
  auto rnd = Random(1);
  for(int i = 0; i < numElts; i++)
  {
    values[i] = uniform(0, numElts, rnd);
    state[i] = false;
  }
  StopWatch sw;
  writeln("Inserting ", numElts, " elements in random order");
  sw.start();
  ulong count;
  for(int i=0; i < numElts; i++)
  {
    bool inserted = set.insert(values[i]);
    if(doCheck) assert(set.check());
    if(!state[values[i]] && !inserted)
    {
      writeln(i, ": value ", values[i], " absent but not inserted");
      assert(false);
    }
    if(state[values[i]] && inserted)
    {
      writeln(i, ": value ", values[i], " already present but inserted");
      assert(false);
    }
    if(!state[values[i]])
    {
      count++;
    }
    state[values[i]] = true;
  }  
  sw.stop();
  writeln("Done inserting ", numElts, " elements with ", count, " distinct values. Time: ", sw.peek().msecs, 
          " milliseconds.");
}

/* Removes the numElts elements inserted by orderedSetInsertTest.
 * check that actual removals are done exactly when the element removed was supposed to be stored.
 * The self-consistency check method check() is optionally called after each removal.
 */

void orderedSetRemoveTest(OrderedSet!(uint) set, uint numElts, bool doCheck)
{
  uint [] values = new uint[numElts];
  bool [] state = new bool[numElts];
  auto rnd = Random(1);
  for(int i = 0; i < numElts; i++)
  {
    values[i] = uniform(0, numElts, rnd);
    state[values[i]] = true;
  }
  StopWatch sw;
  writeln("Removing values: ");
  sw.reset();
  sw.start();
  for(int i = 0; i < numElts; i++)
  {
    bool removed = set.remove(values[i]);
    if(doCheck) assert(set.check());
    if(state[values[i]] && !removed)
    {
      writeln(i, ": Value present but not removed: ", values[i]);
      assert(false);
    }
    if(!state[values[i]] && removed)
    {
      writeln(i, ": Value absent but removed: ", values[i]);
      assert(false);
    }
    state[values[i]] = false;
  }
  sw.stop();
  
  writeln("Done removing ", numElts, " elements. Time: ", sw.peek().msecs, " milliseconds.");
}
