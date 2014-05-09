module coalescedSkipLists;

/* 
 * Alternative implementation of skip lists. Contrary to module skipLists, sibling nodes at different levels are
 * coalesced into one single object. The result however is less efficient than the skipLists implementation
 * with independent nodes.
 * 
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
  skipListNode[] right;
  T value;
  this(T p_value, ulong p_depth)
  {
    right = new skipListNode[p_depth];
    value = p_value;
  }
}

class skipListView(T): OrderedSet!(T)
{
public:
  version(Verbose) bool debugFlag;
  // value k s.t. probability to have one node one level down is 1/k
  int invproba; 
  uint maxDepth;
  // first node at each level. 0 is the full level with all data.
  skipListNode!(T) [] firstNodes;
  // cache to remember the path to access some element when inserting.
  // statistics about the number of hops in each level to access an element.
  // Enables to check that the skip list structure is doing its job.
  skipListNode!(T) [] nodeCache; 
  ulong [] numHops; 
  // more statistics.
  ulong [] numHopCalls; 
  // number of elements in each level, to check for the list consistency.
  ulong [] numElts; 
  // random bit generator to draw the nodes depths.
  Random r; 
  
  this(int p_k, uint p_maxDepth, uint p_seed)
  {
    invproba = p_k;
    maxDepth = p_maxDepth;
    firstNodes = new skipListNode!(T)[maxDepth];
    nodeCache = new skipListNode!(T)[maxDepth];
    numElts = new ulong[maxDepth];
    numHops = new ulong[maxDepth];
    numHopCalls = new ulong[maxDepth];
    r = Random(p_seed);
    version(Verbose) debugFlag = false;
  }

  bool check()
  {
    // not implemented
    return true;
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
  
  void checkCounts()
  {
    for(ulong i = 0; i < maxDepth; i++)
    {
      ulong count = 0;
      skipListNode!(T) node = firstNodes[i];
      while(node !is null)
      {
        count++;
        if(node.right[i] !is null) assert(node.value < node.right[i].value);
        node = node.right[i];
      }
      assert(numElts[i] == count);
    }
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
    
    for(int i = cast(int)firstNodes.length - 1; i >= 0; i--)
    {
      version(Verbose) if(debugFlag) writeln("At depth ", i);
      
      //here node is null or a node at level i s.t. node.value < refValue
      assert(node is null || node.value < refValue);
      
      if(node is null || node.value > refValue) 
      {
        node = firstNodes[i];
      }
      if(node is null || node.value > refValue) 
      {
        node = null;
        continue;
      }
      
      if(node.value == refValue)
      {
        numElts[i]--;
        firstNodes[i] = firstNodes[i].right[i];
        node = null;
        found = true;
        continue;
      }
      
      // here node !is null && node.value < refValue
      
      // horizontal search
      while(node.right[i] !is null && node.right[i].value < refValue) node = node.right[i];
      
      // here node.right is null || node.right.value >= refValue
      // also refValue > node.value (true on the first node by hypothesis and on others since condition 
      // node.value < refValue succeded at previous iteration)
      
      if(node.right[i] !is null && node.right[i].value == refValue){
        numElts[i]--;
        node.right[i] = node.right[i].right[i];
        found = true;
        continue;
      }
    }
    return found;
  }

  // insertion: node st node.value == refValue if it exists
  // otherwise,
  // node st node.val < refValue and (node.right is null || node.right.val > refValue) if it exists
  // otherwise (i.e. if the first node is s.t. firstNode.val > refValue), null
  
  int findPath(T refValue)
  {
    skipListNode!(T) node;
    for(int i = maxDepth - 1; i >= 0; i--)
    { 
      //numHopCalls[i]++;
      if(node is null) node = firstNodes[i];
      if(node is null || node.value > refValue)
      {
        nodeCache[i] = null;
        node = null;
        continue;
      }
      while(node.right[i] !is null && refValue >= node.right[i].value)
      {
        //numHops[i]++;
        node = node.right[i];
      } 
      nodeCache[i] = node;
      if(node.value == refValue) return i;
    }
    return -1;
  }
  
  bool insert(T refValue)
  {
    version(Verbose) if(debugFlag) 
    {
      writeln("\nInserting ", refValue);
      writeln("Finding path to element");
    }
    int level = findPath(refValue);
    version(Verbose) if(debugFlag) writeln("level = ", level);
    if(level >= 0) 
    {
      // element is already in the tree
      version(Verbose) if(debugFlag) writeln("Element is already in the list");
      return false; 
    }
    
    ulong s;
    auto ln = maxDepth;
    while(s < ln - 1 && uniform(0, 1<<invproba, r) == 0) s++;
    // element will be inserted in levels 0 ... s
    skipListNode!(T) newNode = new skipListNode!(T)(refValue, s+1);
    for(int i = 0; i < s + 1; i++)
    {
      numElts[i]++;
      version(Verbose) if(debugFlag) writeln("Inserting at level ", i);
      if(nodeCache[i] is null) // insertion at the beginning of the list
      {
        version(Verbose) if(debugFlag) writeln("Inserting at beginning ");
        assert(firstNodes[i] is null || refValue < firstNodes[i].value);
        if(firstNodes[i] !is null)
        {
          assert(firstNodes[i].right.length >i);
          newNode.right[i] = firstNodes[i];
        }
        firstNodes[i] = newNode;
      }
      else
      {
        assert(nodeCache[i].value < refValue && (nodeCache[i].right[i] is null || nodeCache[i].right[i].value > refValue));
        skipListNode!(T) prevRightNeighbor = nodeCache[i].right[i];
        // nodeCache[i] right neighbor is newNode
        nodeCache[i].right[i] = newNode;
        // newNode right neigbor is prevRightNeighbor
        newNode.right[i] = prevRightNeighbor;
      }
    }
    return true;
  }
}

void coalescedSkipListUnitTest(uint numElts)
{
  writeln("\n**** Coalesced skip lists unit testing ****");
  int logproba = 2;
  int depth = 10;
  writeln("Creating a skip list with proba 2^-", logproba," and depth ", depth);
  skipListView!(uint) l = new skipListView!(uint)(logproba, depth, 3); 
  
  orderedSetInsertTest(l, numElts, false);
  l.checkCounts();
  l.displayCounts();
  
  orderedSetRemoveTest(l, numElts, false);
  l.checkCounts();
  l.displayCounts();
}


unittest{
  skipListUnitTest(1000000);
}