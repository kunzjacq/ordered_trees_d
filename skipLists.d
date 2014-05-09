module skipLists;

/* 
 * Implementation of skip lists, a linked list with additional sparse linked lists to do larger hops 
 * when searching for an element.
 * see http://en.wikipedia.org/wiki/Skip_list
 * or 
 * ftp://ftp.cs.umd.edu/pub/skipLists/skiplists.pdf (original paper)
 * A probability p is fixed at construction. Then the skip list consists of several linked lists l_0, ...,l_k.
 * l_0 is the regular linked list of the stored elements. If an element is present in l_i, it is in l_i+1 with
 * probability p: the hops in l_i+1 are therefore on average p times larger than in l_i. Their use ensures logarithmic
 * search time in the skipLists if p > 0.
 * Main class is skipListView(T).
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

import std.stdio;
import std.random;
import std.datetime;
import orderedSet;

//version = Verbose;
//to enable the printout of various messages (must also be enabled dynamically with setDebugFlag(true))

class skipListNode(T)
{
  skipListNode right;
  skipListNode up;
  T value;
}

class skipListView(T):  OrderedSet!(T)
{
public:
  // flag to dynamically enable debug messages.
  version(Verbose) bool debugFlag;
  // maximal number of lists
  int maxDepth;
  // value k s.t. probability to have one node one level down is 1/k
  int invproba; 
  // first node at each level. 0 is the full level with all data.
  skipListNode!(T) [] firstNodes;
  // cache to remember the path to access some element when inserting.
  skipListNode!(T) [] nodeCache; 
  // statistics about the number of hops in each level to access an element.
  // Enables to check that the skip list structure is doing its job of reducing the number of hops required to
  // find a node.
  ulong [] numHops; 
  // more statistics.
  ulong [] numHopCalls; 
  // number of elements in each level, to check for the list consistency.
  ulong [] numElts; 
  // random bit generator to draw the nodes depths.
  Random r; 

  this(int p_invproba, int p_maxDepth, uint p_seed)
  {
    maxDepth = p_maxDepth;
    invproba = p_invproba;
    firstNodes = new skipListNode!(T)[p_maxDepth];
    nodeCache = new skipListNode!(T)[p_maxDepth];
    numElts = new ulong[p_maxDepth];
    numHops = new ulong[p_maxDepth];
    numHopCalls = new ulong[p_maxDepth];
    r = Random(p_seed);
    version(Verbose) debugFlag = false;
  }

  void setDebugFlag(bool p_flag)
  {
    version(Verbose) debugFlag = p_flag;
  }
  
  void printHops()
  {
    for(ulong i = 0; i < firstNodes.length; i++)
    {
      if(numHopCalls[i] > 0) 
      {
        writeln("average hops at depth ", i,": ", cast(double)(numHops[i])/cast(double)(numHopCalls[i]));
      }
    }
  }

  /*
   * Checks (part of) the structure of a skip list: namely that the linked list values are increasing, and that
   * the recorded number of elements in each list corresponds to its content.
   */
  bool check()
  {
    bool ok = true;
    for(ulong i = 0; i < firstNodes.length; i++)
    {
      ulong count = 0;
      skipListNode!(T) node = firstNodes[i];
      while(node !is null)
      {
        count++;
        if(node.right !is null && node.value >= node.right.value)
        {
          ok = false;
          break;
        }
        node = node.right;
      }
      if(numElts[i] != count) {ok = false; break;}
      version(Verbose)
      {
        writeln("i: ", i, " ; stored count: ", numElts[i]," ; recomputed count: ", count);
      }
    }
    return ok;
  }

  void displayCounts()
  {
    for(ulong i = 0; i < firstNodes.length; i++)
    {
      writeln("depth: ", i, " count: ", numElts[i]);
    }
  }
  bool remove(T refValue)
  {
    version(Verbose) if(debugFlag) writeln("Removing ", refValue);
    skipListNode!(T) node;

    bool found = false;

    for(int i = maxDepth - 1; i >= 0; i--)
    {
      version(Verbose) if(debugFlag) writeln("At depth ", i);

      //here node is null or a node at level i s.t. node.value < refValue
      assert(node is null || node.value < refValue);

      if(node is null) node = firstNodes[i];
      if(node is null || node.value > refValue) 
      {
        node = null;
        continue;
      }

      if(node.value == refValue){
        numElts[i]--;
        firstNodes[i] = firstNodes[i].right;
        node = null;
        found = true;
        continue;
      }

      // here node !is null && node.value < refValue

      // horizontal search
      while(node.right !is null && node.right.value < refValue) node = node.right;

      // here node.right is null || node.right.value >= refValue
      // also refValue > node.value (true on the first node by hypothesis and on others since condition 
      // node.value < refValue succeded at previous iteration)

      if(node.right !is null && node.right.value == refValue){
        numElts[i]--;
        node.right = node.right.right;
        found = true;
        node = node.up;
        continue;
      }

      if(refValue > node.value) node = node.up;
      else node = null;
    }
    return found;
  }

  bool insert(T refValue)
  {
    version(Verbose) if(debugFlag) writeln("\nInserting ", refValue);

    //finding path
    int ln = maxDepth;
    int level = -1;
    skipListNode!(T) node;
    
    while(node is null && ln > 0)
    {
      ln--;
      if(firstNodes[ln] !is null && firstNodes[ln].value <= refValue) 
      {
        node = firstNodes[ln];
      }
      nodeCache[ln] = node;
    }
    if(node !is null)
    {
      for(int i = ln; i >= 0; i--)
      { 
        version(Verbose) 
        {
          if(debugFlag) writeln("Building path to value ", refValue, " at depth ", i);
          numHopCalls[i]++;
        }
        while(node.right !is null && refValue >= node.right.value)
        {
          version(Verbose) numHops[i]++;
          node = node.right;
        } 
        nodeCache[i] = node;
        if(node.value == refValue)
        {
          level =i;
          break;
        }
        node = node.up;
      }
    }
    
    version(Verbose) 
    {
      if(debugFlag) 
      {
        if(level == -1) writeln("Value not found");
        else writeln("Value found at depth", level);
      }
    }
    if(level >= 0) 
    {
      // element is already in the tree
      return false; 
    }

    // when level = -1 (element not found, has to be inserted), meaning of nodeCache: 
    // if nodeCache[i] = null, new element has to be inserted in first position at level i
    // (i.e if firstNode[i] exists, firstNode[i].value > refValue)
    // else nodeCache[i].value < refValue and new element has to be inserted after nodeCache[i]
    // (i.e if nodeCache[i].right exists, nodeCache[i].right.value > refValue)

    ulong s;
    while(s < maxDepth - 1 && uniform(0, invproba, r) == 0) s++;
    // element will be inserted in levels 0 ... s
    skipListNode!(T) prevNode, newNode;
    for(int i = 0; i <= s ; i++)
    {
      numElts[i]++;
      version(Verbose) if(debugFlag) writeln("Inserting at level ", i);

      newNode = new skipListNode!(T);
      newNode.value = refValue;
      if(nodeCache[i] is null) // insertion at the beginning of the list
      {
        version(Verbose) if(debugFlag) writeln("Inserting at beginning ");
        if(firstNodes[i] !is null)
        {
          assert(refValue < firstNodes[i].value);
          newNode.right = firstNodes[i];
        }
        firstNodes[i] = newNode;
      }
      else
      {
        assert(nodeCache[i].value < refValue && (nodeCache[i].right is null || nodeCache[i].right.value > refValue));
        skipListNode!(T) prevRightNeighbor = nodeCache[i].right;
        // nodeCache[i] right neighbor is newNode
        nodeCache[i].right = newNode;
        // newNode right neigbor is prevRightNeighbor
        newNode.right = prevRightNeighbor;
      }
      newNode.up = prevNode;
      prevNode = newNode;
    }
    return true;
  }
}

void skipListUnitTest(uint numElts)
{
  writeln("\n**** Skip lists unit testing ****");
  int invproba = 4;
  int depth = 10;
  writeln("Creating a skip list with proba 1/", invproba," and depth ", depth);
  skipListView!(uint) l = new skipListView!(uint)(invproba, depth, 3); 
 
  orderedSetInsertTest(l, numElts, false);
  l.check();
  l.displayCounts();
  l.printHops();

  orderedSetRemoveTest(l, numElts, false);
  l.check();
  l.displayCounts();
  l.printHops();
}

unittest{
  skipListUnitTest(1000000);
}