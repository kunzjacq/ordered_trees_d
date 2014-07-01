module Btree;

/* Implementation of B-trees.
 * A B-tree is a k-ary tree for some k > 1 with k - 1 values v_1, ..., v_k-1 stored in the node. 
 * The values in subtree 1 <= i <= k of a node  are > v_{i-1} (if i>=2) and < v_i (if i < k).
 * see http://en.wikipedia.org/wiki/B-tree or
 * http://infolab.usc.edu/csci585/Spring2010/den_ar/indexing.pdf (original paper)
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
//to enable the printout of various messages (must also be enabled dynamically when calling rebalanceOrJoin)

class btreeNode(T){
  T[] keys;
  size_t numSubnodes;
  btreeNode[] subnodes;
  btreeNode right; // pointer to its left neighbor if there is one with the same parent or a different parent.

  this(uint p_r){
    keys = new T[2*p_r];
    subnodes = new btreeNode!(T)[2*p_r];
  }

  bool rebalanceOrJoin(bool debugFlag)
  {
    assert(right !is null);
    ulong l = subnodes.length;
		version(Debug) if(debugFlag) if(numSubnodes != l/2 - 1 && right.numSubnodes != l/2 - 1)
    {
      writeln(l/2, " ", numSubnodes, " ", right.numSubnodes);
    }
    assert(numSubnodes == l/2 - 1 || right.numSubnodes == l/2 - 1);
    if(right.numSubnodes > l/2)
    {
      // rebalance from right to left
      version(Debug) if(debugFlag) writeln("Rebalancing from right to left");
      subnodes[numSubnodes] = right.subnodes[0];
      //no need to update subnodes[numSubnodes-1].right as no node is removed/deleted
      keys[numSubnodes] = right.keys[0];
      numSubnodes++;
      right.removeNode(0);
      return false; // no joining occurred
    }
    else if(numSubnodes > l/2)
    {
      // rebalance from left to right
      version(Debug) if(debugFlag) writeln("Rebalancing from left to right. right.numSubnodes: ", right.numSubnodes);
      right.insertNode(subnodes[numSubnodes - 1], 0);
      subnodes[numSubnodes - 1] = null;
      right.keys[0] = keys[numSubnodes - 1];
      numSubnodes--;
      return false; // no joining occurred
    }
    else
    {
      // one node has l/2 subnodes, the other has l/2-1 subnodes
      // join them
      version(Debug) if(debugFlag) writeln("Joining");
      join();
      return true;
    }
  }

  void join() // join this and this.right
  {
    assert(right !is null);
    ulong l = subnodes.length;
    size_t numJoinedSubnodes = numSubnodes + right.numSubnodes;
    assert(numJoinedSubnodes < l);
    assert(numSubnodes > 0 && right.numSubnodes > 0); 
    for(uint i = 0; i < right.numSubnodes ; i++)
    {
      keys[numSubnodes+i] = right.keys[i];
      subnodes[numSubnodes+i] = right.subnodes[i];
    }
    // no need to update .right pointers of subtrees as there was no addition/removal at this level
    assert(subnodes[numSubnodes - 1] is null || subnodes[numSubnodes - 1].right == subnodes[numSubnodes]);
    right = right.right;
    numSubnodes = numJoinedSubnodes;
  }

  void split(btreeNode!(T) newNode)
  {
		size_t l = subnodes.length;
    assert(numSubnodes == l);
    size_t r = l/2;
    newNode.right = right;
    right = newNode;
    numSubnodes = r;
    right.numSubnodes = r;
    for(uint i = 0; i < right.numSubnodes ; i++)
    {
      right.keys[i] = keys[r + i];
    }
    if(subnodes[0] !is null)
    {
      for(uint i = 0; i < right.numSubnodes ; i++)
      {
        right.subnodes[i] = subnodes[r + i];
        subnodes[r + i] = null;
      }
      // no need to update .right pointers of subtrees as there was no addition/removal at this level
      assert(subnodes[r-1].right == right.subnodes[0]);
    }
  }

  bool insert(T refValue) // insert in current node (to be used only on a leaf)
  {
    ulong l = subnodes.length;
    assert(numSubnodes < l);
    assert(subnodes[0] is null); // must be used only on a leaf

    int i;
    while(keys[i] < refValue && i < numSubnodes) i++;
    if(i < numSubnodes && keys[i] == refValue)
    {
      //value already present
      return false;
    }
    for(int j = cast(int)(numSubnodes); j > i; j--)
    {
      keys[j] = keys[j - 1];
    }
    keys[i] = refValue;
    numSubnodes++; // here numSubnodes may be equal to l, which is a temporary invariant violation
    return true;
  }

  bool remove(T refValue) // remove in current node (to be used only on a leaf)
  {
    ulong l = subnodes.length;
    assert(subnodes[0] is null); // must be used only on a leaf

    int i;
    while(keys[i] < refValue && i < numSubnodes) i++;
    if(i == numSubnodes || keys[i] != refValue)
    {
      //value not found
      return false;
    }
    for(int j = i + 1; j  < cast(int)(numSubnodes); j++)
    {
      keys[j - 1] = keys[j];
    }
    numSubnodes--; // here numSubnodes may be equal to l/2-1, which is a temporary invariant violation
    return true;
  }
  
  /* inserts a subnode in 'this' at position i. Only 'this' is modified, 
   right pointers of the subnodes are assumed to be already set correctly */
  void insertNode(btreeNode!(T) n, uint i) 
  {
    ulong l = subnodes.length;
    assert(numSubnodes < l);
    assert(i <= numSubnodes);
    for(int j = cast(int)(numSubnodes); j > i; j--)
    {
      keys[j] = keys[j - 1];
      subnodes[j] = subnodes[j - 1];
    }
    if(n !is null) // not at a leaf
    {
      keys[i] = n.keys[0];
      subnodes[i] = n;
      //do NOT modify the .right pointers of n and its neighbors here, it is already done
    }
    numSubnodes++; // here numSubnodes may be equal to l, which is a temporary invariant violation

  }

  /* remove subkey / subnode in 'this' at position i. Only 'this' is modified, 
   right pointers of the subnodes are assumed to be already set correctly */
  void removeNode(uint i) 
  {
    ulong l = subnodes.length;
    assert(i < numSubnodes);
    for(uint j = i + 1; j < cast(uint)(numSubnodes); j++)
    {
      keys[j - 1] = keys[j];
      subnodes[j - 1] = subnodes[j];
    }
    subnodes[numSubnodes - 1] = null;
    numSubnodes--; // here numSubnodes may be equal to l/2-1, which is a temporary invariant violation
  }
}

class btree(T): OrderedSet!(T)
{
  btreeNode!(T) root;
  uint r; // minimum number of subnodes of a node (except for the root)
  // for any node other than the root its number k of subnodes must be r <= k < 2r.
  // before a split, the number of subnodes is temporarily equal to 2r.
  // subnode[i] has all its key values v_i satisfying key[i] <= v_i < key[i+1] .
  // except for i = numSubnodes where they only satisfy key[i] <= v_i
  uint depth;
  uint maxDepth;
  btreeNode!(T) [] nodeCache;
  uint [] branchCache;
  bool debugFlag;

  this(uint p_r, uint p_maxDepth)
  {
    r = p_r;
    depth = 0;
    maxDepth = p_maxDepth;
    nodeCache = new btreeNode!(T)[maxDepth + 1];
    branchCache = new uint[maxDepth];
    root = new btreeNode!(T)(p_r);
    debugFlag = false;
  }

  void setDebugFlag(bool p_flag)
  {
    debugFlag = p_flag;
  }

  void recurseSplit(uint currentDepth)
  {
    int currentDepth_s = cast(int)(currentDepth);
    do
    {
      version(Debug) if(debugFlag) writeln("in recurseSplit at depth ", currentDepth_s, " / ", depth);
      auto n = nodeCache[currentDepth_s];
      ulong l = n.subnodes.length;
      if(currentDepth_s > 0) assert(nodeCache[currentDepth_s - 1].subnodes[branchCache[currentDepth_s - 1]] == n); 
      if(n.numSubnodes == l)
      {
        version(Debug) 
        {
          if(debugFlag)
          {
            write("Overfull node");
            if(currentDepth_s > 0) write(" of subindex ", branchCache[currentDepth_s - 1]);
            writeln();
          }
        }
        auto newNode = new btreeNode!(T) (r);
        n.split(newNode);
        assert(n.numSubnodes < l && newNode.numSubnodes < l);
        if(currentDepth_s == 0)
        {
          // we just split the root and need to add a layer
          if(depth == maxDepth)
          {
            throw new Error("Should increase depth, but max depth reached");
          }
          assert(n == root);
          depth++;
          version(Debug) if(debugFlag) writeln("Increasing depth");
          auto newRoot = new btreeNode!(T) (r);
          newRoot.insertNode(n, 0);
          newRoot.insertNode(newNode, 1);
          root = newRoot;
        }
        else
        {
          // need to insert newNode in position branchCache[currentDepth_s - 1] + 1
          // in node nodeCache[currentDepth_s - 1]
          nodeCache[currentDepth_s - 1].insertNode(newNode, branchCache[currentDepth_s - 1] + 1);
        }
      }
      else return; // no modification at current depth, hence no need to continue
      currentDepth_s--;
    } 
    while(currentDepth_s >= 0);
  }


  bool insert(T refValue)
  {
    return insertAux(refValue, root, 0);
  }
  
  bool insertAux(T refValue, btreeNode!(T) currentNode, uint currentDepth)
  {
    nodeCache[currentDepth] = currentNode;
    if(currentDepth == depth) // at the bottom layer, need to insert in currentNode
    {
      bool inserted = currentNode.insert(refValue);
      // now the current node may be over-full, we have to restore size invariants
      if(inserted) recurseSplit(currentDepth);
      return inserted;
    }
    else
    {
      int i;
      if(currentNode.keys[0] > refValue)
      {
        currentNode.keys[0] = refValue;
      }
      else
      {
        while(i + 1 < currentNode.numSubnodes && currentNode.keys[i + 1] <= refValue) i++;
        // one has i == numSubNodes - 1 || currentNode.keys[i+1] > refValue
        // For the parallel algorithms described in "Efficient Locking of Concurrent Operations on B-trees" 
        // (P.L. Lehman), in the case where i = numSubnodes - 1, one would need to check the leftmost key 
        // of the right node and to insert in that node if required
      }
      branchCache[currentDepth] = i;
      return insertAux(refValue, currentNode.subnodes[i], currentDepth + 1);
    }
  }

  void recurseJoin(uint currentDepth)
  {
    int currentDepth_s = currentDepth;
    do
    {
      version(Debug) if(debugFlag) writeln("in recurseJoin at depth ", currentDepth_s);
      auto n = nodeCache[currentDepth_s];
      ulong l = n.subnodes.length;
      if(currentDepth_s > 0)
      {
        if(n.numSubnodes < l/2)
        {
          version(Debug) if(debugFlag) writeln("underfull node");
          uint idx; // index of node to remove, if any
          assert(nodeCache[currentDepth_s - 1].subnodes[branchCache[currentDepth_s - 1]] == n); 
          btreeNode!(T) m;
          if(branchCache[currentDepth_s - 1] < nodeCache[currentDepth_s - 1].numSubnodes - 1) // there is a right node
          {
            version(Debug) if(debugFlag) writeln("with a right node");
            idx = branchCache[currentDepth_s - 1] + 1;
            assert(nodeCache[currentDepth_s - 1].subnodes[branchCache[currentDepth_s - 1] + 1] == n.right); 
            m = n;
          }
          else if(branchCache[currentDepth_s - 1] > 0) // there is a left node
          {
            version(Debug) if(debugFlag) writeln("with a left node");
            idx = branchCache[currentDepth_s - 1];
            assert(nodeCache[currentDepth_s - 1].numSubnodes > idx);
            m = nodeCache[currentDepth_s - 1].subnodes[idx - 1];
            assert(m.right == n);
          }
          else 
          {
            // underfull node with no neighbor
            assert(currentDepth_s == 1);
          }
          
          bool removedNode = false;
          version(Debug) if(debugFlag) writeln("doing rebalanceOrJoin");
          if(m !is null) removedNode = m.rebalanceOrJoin(debugFlag);
          version(Debug) if(debugFlag) writeln("node to remove: ", removedNode);
          if(removedNode) 
          {
            // remove joined node from parent
            nodeCache[currentDepth_s - 1].removeNode(idx);
          }
          else if(nodeCache[currentDepth_s - 1].subnodes[idx] !is null)
          {
            // update key of right node in parent node
            nodeCache[currentDepth_s - 1].keys[idx] = nodeCache[currentDepth_s - 1].subnodes[idx].keys[0];
          }
        }
      }
      else if(depth > 0 && n.numSubnodes == 1) // currentDepth == 0
      {
        assert(n == root);
        root = root.subnodes[0];
        depth--;
      }
      else return; // no modification at current depth, hence no need to continue
      currentDepth_s--;
    } 
    while(currentDepth_s >= 0);
  }
  
  bool remove(T refValue)
  {
    version(Debug) 
    {
      if(debugFlag)
      {
        writeln("\nremove: searching for value ", refValue);
      }
    }
    return removeAux(refValue, root, 0);
  }
  
  bool removeAux(T refValue, btreeNode!(T) currentNode, uint currentDepth)
  {
    nodeCache[currentDepth] = currentNode;
    if(currentDepth == depth) // at the bottom layer, need to remove in currentNode
    {
      bool removed = currentNode.remove(refValue);
      // now the current node may be under-full, we have to restore size invariants
      if(removed) recurseJoin(currentDepth);

      return removed;
    }
    else
    {
      if(currentNode.keys[0] > refValue) return false; // value is not here
      int i;
      while(i + 1 < currentNode.numSubnodes && currentNode.keys[i + 1] <= refValue) i++;
      // i == numSubNodes - 1 || currentNode.keys[i+1] > refValue
      assert(currentNode.keys[i] <= refValue && (i == currentNode.numSubnodes - 1 || currentNode.keys[i+1] > refValue));
      branchCache[currentDepth] = i;
      version(Debug) 
      {
        if(debugFlag)
        {
          write("Keys:");
          for(ulong j=0; j < currentNode.numSubnodes;j++) write(" ",currentNode.keys[j]);
          writeln("\nbranch to ", i," at depth ", currentDepth);
        }
      }
      return removeAux(refValue, currentNode.subnodes[i], currentDepth + 1);
    }
  }

  ulong checkRightRelation(btreeNode!(T) currentNode)
  {
    return  checkRightRelationAux(currentNode, 0);
  }

  ulong checkRightRelationAux(btreeNode!(T) currentNode, uint currentDepth)
  {
    ulong count = 0;
    for(size_t i = 0; i < currentNode.numSubnodes; i++)
    {
      if(currentNode.subnodes[i] !is null)
      {
        count += checkRightRelationAux(currentNode.subnodes[i], currentDepth + 1);
        if(i + 1 < currentNode.numSubnodes)
        {
          if(currentNode.subnodes[i].right != currentNode.subnodes[i + 1])
          {
            writeln("Right linking failure at depth ", currentDepth + 1, " and node ", i);
            writeln("left.right: ", cast(void*) currentNode.subnodes[i].right);
            writeln("right: ", cast(void*) currentNode.subnodes[i + 1]);
            assert(false);
          }
          auto leftRight = currentNode.subnodes[i].subnodes[currentNode.subnodes[i].numSubnodes - 1];
          auto rightLeft = currentNode.subnodes[i+1].subnodes[0];
          if(leftRight !is null && leftRight.right != rightLeft)
          {
            writeln("Right linking cross-node failure at depth ", currentDepth+2, " and node ", i);
            writeln("leftright.right: ", cast(void*)leftRight.right);
            writeln("rightleft: ", cast(void*)rightLeft);
            assert(false);
          }
        }
      }
    }
    if(currentNode.subnodes[0] is null) count += currentNode.numSubnodes;
    return count;
  }

  void print()
  {
    printAux(root,0);
  }

  void printAux(btreeNode!(T) currentNode, uint currentDepth)
  {
    if(currentDepth == depth) //at a leaf node
    {
      for(size_t i = 0; i < currentNode.numSubnodes; i++)
      {
        write(currentNode.keys[i], " ");
      }
      write("/");
    }
    else
    {
      for(size_t i = 0; i < currentNode.numSubnodes; i++)
      {
        printAux(currentNode.subnodes[i], currentDepth + 1);
      }
    }
    if(currentDepth == 0) writeln();
  }

  bool check(){return true;}
}

void btreeUnitTest(uint numElts)
{
  writeln("\n**** B-Tree unit testing ****");
  int r = 7;
  int depth = 10;
  writeln("Creating a B-Tree with between ", r," and ", 2*r-1, " elements per node and of max depth ", depth);
  auto t = new btree!(uint)(r, depth); 
  writeln("tree depth: ", t.depth);

  orderedSetInsertTest(t, numElts, false);

  //t.print();
  writeln("tree depth: ", t.depth);
  writeln("number of elements: ", t.checkRightRelation(t.root)); 

  orderedSetRemoveTest(t, numElts, false);

  writeln("tree depth: ", t.depth);
  writeln("number of elements: ", t.checkRightRelation(t.root)); 
}

unittest
{
  btreeUnitTest(1000000);
}