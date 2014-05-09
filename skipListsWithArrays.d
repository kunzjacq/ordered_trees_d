module skipListsWithArray;

/*
 * A variant of skip lists where each node stores not one but several elements in an array. This improves
 * significantly the skip list performance. main class is skipListView(T).
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

class partialArray(T)
{
  T[] value;
  ulong numValues;
  ulong level;

  this(ulong n, ulong p_level)
  {
    value = new T[n];
    level = p_level;
  }

  T min()
  {
    assert(numValues > 0);
    return value[0];
  }

  T max()
  {
    assert(numValues > 0);
    return value[numValues - 1];
  }

  // returns whether node contains v. If so, returns the index of v. Otherwise returns the lowest index s.t. 
  // values[index]>=v, and numValues if all values are less than v.
  bool hasTop(T v, ref ulong idx)
  {
    if(value[0]>v)
    {
      idx=0;
      return false;
    }
    if(value[numValues-1] < v)
    {
      idx=numValues;
      return false;
    }
    ulong a=-1, b = numValues-1;
    while(b>a+1)
    {
      ulong c=(a+b+1)/2;
      if(value[c] >= v) b=c; else a=c;
    }
    idx = b;
    assert(value[b]>=v);
    return(value[b] == v);
  }

  // returns whether node contains v. If so, idx is set to the index of v. 
  // no guarantee is made on the idx if v is not present in the node.
  bool has(T v, ref ulong idx)
  {
    if(value[0] > v || value[numValues-1] < v)
    {
      return false;
    }
    ulong a, b = numValues;
    while(b > a + 1)
    {
      ulong c = (a + b)/2;
      if(value[c] > v) b=c; else a=c;
    }
    idx = a;
    assert(value[a] <= v);
    return(value[a] == v);
  }

  T popVal()
  {
    assert(numValues > 0);
    numValues--;
    return value[numValues];
  }
  void insert(T refValue, ulong idx)
  {
    assert(numValues < value.length);
    for(int j = cast(int)numValues - 1; j >= cast(int)idx; j--)
    {
      value[j + 1] = value[j];
    }
    value[idx] = refValue;
    numValues++;
    assert(ordered());
  }

  bool ordered()
  {
    bool res = true;
    if (numValues == 0) return true;
    for(ulong i=0; i < numValues-1; i++) res &= value[i] < value[i+1];
    return res;
  }

  void remove(ulong idx)
  {
    assert(numValues > idx);
    for(ulong j = idx; j < numValues - 1; j++) value[j] = value[j + 1];
    numValues--;
  }
}

class skipListNode(T)
{
  skipListNode right;
  skipListNode up;
  partialArray!(T) values;

  this(ulong n, ulong p_level)
  {
    values = new partialArray!(T)(n, p_level);
  }

  this(skipListNode!(T) node)
  {
    values = node.values;
  }
}

class skipListView(T):  OrderedSet!(T)
{
public:
  version(Verbose) bool debugFlag;
  int maxDepth;
  // int k s.t. probability to have one node down is 1/k
  int invproba; 
  // first node at each level. 0 is the full level with all data.
  skipListNode!(T) [] firstNodes;
  // cache to remember the path to access some element when inserting.
  skipListNode!(T) [] nodeCache; 
  // statistics about the number of hops in each level to access an element.
  // Enables to check that the skip list structure is doing its job.
  ulong [] numHops; 
  // more statistics.
  ulong [] numHopCalls; 
  // number of elements in each level, to check for the list consistency.
  ulong [] numElts; 
  Random r; // random bit generator to draw the nodes depths.
  ulong numEltsPerNode;
  ulong numNodesCreated;

  this(int p_invproba, int p_maxDepth, ulong p_numEltsPerNode, uint p_seed)
  {
    invproba = p_invproba;
    maxDepth = p_maxDepth;
    firstNodes = new skipListNode!(T)[p_maxDepth];
    nodeCache = new skipListNode!(T)[p_maxDepth];
    numElts = new ulong[p_maxDepth];
    numHops = new ulong[p_maxDepth];
    numHopCalls = new ulong[p_maxDepth];
    numEltsPerNode = p_numEltsPerNode;
    r = Random(p_seed);
    version(Verbose) debugFlag = false;
  }

  void setDebugFlag(bool p_flag)
  {
    version(Verbose) debugFlag = p_flag;
  }
  
  void printStats()
  {
    version(Verbose)
    {
      for(ulong i = 0; i < firstNodes.length; i++)
      {
        if(numHopCalls[i] > 0) writeln("average hops at depth ", i,": ", cast(double)(numHops[i])/cast(double)(numHopCalls[i]));
      }
      writeln("Number of nodes created: ", numNodesCreated);
    }
  }

  bool check()
  {
    bool ok = true;
    for(ulong i = 0; i < firstNodes.length; i++)
    {
      ulong count = 0;
      skipListNode!(T) node = firstNodes[i];
      while(node !is null)
      {
        if(node.values.numValues == 0)
        {
          writeln("node with no element");
          ok = false;
          break;
        }
        count+=node.values.numValues;
        if(node.right !is null) 
        {
          assert(node.right.values.numValues > 0);
          if(node.values.max() >= node.right.values.min())
          {
            writeln("order violation: at depth ", i, ", ", node.values.max(), " should be < to ", node.right.values.min());
            ok = false;
            break;
          }
        }
        node = node.right;
      }
      writeln("i: ", i, " ; stored count: ", numElts[i]," ; recomputed count: ", count);
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

      assert(node is null || node.values.numValues > 0);
      //here node is null or a node at level i s.t. node.value < refValue
      assert(node is null || node.values.min() <= refValue);

      if(node is null) node = firstNodes[i];

      if(node is null || node.values.min() > refValue) 
      {
        node = null;
        continue;
      }

      ulong idx;
      if(node.values.has(refValue,idx))
      {
        if(node.values.numValues > 1)
        {
          // only remove refValue from values once, this removes refValue from 
          // node and all nodes above; then return
          for(int j = 0; j <= i; j++) numElts[j]--;
          node.values.remove(idx);
          return true;
        }
        else
        {
          // only one value left: when we remove it, the node becomes empty
          // we have to delete it and the nodes above it
          assert(node == firstNodes[i]);
          numElts[i]--;
          firstNodes[i] = firstNodes[i].right;
          if(i > 0)
          {
            node = firstNodes[i - 1]; 
            continue;
          }
          else return true;
          // one can't do node = node.up because although node is the first element at level i,
          // node.up may not be the first element at level i - 1
          // we don't know its left neighbor and can't use the same case as here
        }
      }
      // here node !is null && node.values.min() <= refValue && !node.values.has(refValue)
      // horizontal search
      while(node.right !is null && node.right.values.max() < refValue) node = node.right;

      // what we want: if there is a node n that contains refVal, the loop stops with node.right = n
      // if not, and there is n s.t. n.values.min() > refValue, the loop stops on node.right = n
      // if not it stops with node = last node (and hence node.right = null)

      // if there is a node n that contains refVal, it is the unique node n s.t. 
      // n.values.min() <= refVal && n.values.max () >= refVal
      // to fetch it, as long as node.right.min() >= refVal || node.right.max() < refVal, one can do node = node.right 
      // but to stop in the second case, one only considers the condition node.right.max() < refVal

      if(node.right !is null && node.right.values.has(refValue, idx))
      {
        for(int j = 0; j <= i; j++) numElts[j]--;
        if(node.right.values.numValues > 1)
        {
          // only remove refValue from values once, this removes refValue from 
          // node and all nodes above; then return
          node.right.values.remove(idx);
        }
        else
        {
          // only one value left: we we remove it, the node becomes empty
          // we have to delete the node at all depths
          skipListNode!(T) nodeToDelete = node.right;
          for(; i > 0; i--) 
          {
            node.right = nodeToDelete.right;
            node = node.up;
            nodeToDelete = nodeToDelete.up;
            while(node.right != nodeToDelete) node = node.right;
          }
          node.right = nodeToDelete.right;
        }
        return true;
      }
      else node = node.up;
    }
    return found;
  }

  bool insert(T refValue)
  {
    //finding path
    int ln = maxDepth;
    skipListNode!(T) node;
    T valueToInsert;
    bool hasValueToInsert = false;

    skipListNode!(T) leftmostFirstNode;
    // attempt to find a node to the left of the node looked for
    while(node is null && ln > 0)
	{
      ln--;
      if(firstNodes[ln] !is null)
      {
        if(ln+1 >= nodeCache.length || firstNodes[ln+1] is null || firstNodes[ln] != firstNodes[ln+1].up) 
          // firstNodes[ln] is strictly on the left of firstNodes[ln+1] or firstNode[ln+1] does not exist
        {
          leftmostFirstNode = firstNodes[ln];
        }
        if(firstNodes[ln].values.max() < refValue)
        { 
          node = firstNodes[ln];
        }
      }
      nodeCache[ln] = node;
    }
    if(node is null)
    {
      //two cases: either the tree is empty
      // => create a node with the value to be inserted
      //or there is a non-null firstNode but each firstNode is s.t. firstNode.max >= refValue()
      // => insert in the leftmost firstNode
      if(leftmostFirstNode !is null)
      {
        node = leftmostFirstNode;
      }
      else
      {
        valueToInsert = refValue;
        hasValueToInsert = true;
      }
    }
    if(node !is null)
    {
      for(int i = ln; i >= 0; i--)
      { 
        version(Verbose) numHopCalls[i]++;
        // attempt to insert in the first node with a left neighbor prevNode s.t. prevNode.value.max() < refValue
        while(node.right !is null && node.right.values.max() < refValue)
        {
          version(Verbose) numHops[i]++;
          node = node.right;
        } 
        // node.right is null || node.right.values.max() >= refValue

        version(Verbose) if(debugFlag) writeln("Path to value ", refValue, " at depth ", i,": ", cast(void*) node);
        if(i == 0)
        {
          if(node.right !is null && node.values.max() < refValue) 
          {
            node = node.right;
          }
          nodeCache[0] = node;
          assert(node.right is null || node.values.max() >= refValue);
          // node.right is null || node.values.max() >= refValue (and therefore refValue can't be right to node)
          // if node has a left neighbor prevNode, prevNode.values.max() < refValue (and therefore refValue can't be there)
          // therefore if node.right is null, the value can be inserted in node
          // if node.right !is null, it can be inserted locally, too
          // in any case, if the value is already present, it is in node 'node'

          ulong idx;
          if(node.values.max() < refValue)
          {
            // simple case: insertion at the end of current level
            hasValueToInsert = true;
            valueToInsert = refValue;
          }
          else
          {
            //bool found = node.values.search(refValue, idx);
            bool found = node.values.hasTop(refValue, idx);
            if (found) return false;
            // value not found: insert it
            if(node.values.numValues == numEltsPerNode)
            {
              // if node is full, remove its max value and put it in a new node later
              valueToInsert = node.values.popVal();
              if(node.right !is null && node.right.values.numValues < numEltsPerNode)
              {
                node.right.values.insert(valueToInsert, 0);
                node.values.insert(refValue, idx);
                for(int j = 0; j <= node.right.values.level; j++) numElts[j]++;
                return true;
              }
              else{
              hasValueToInsert = true;
              }
            }
            else
            {
              for(int j = 0; j <= node.values.level; j++) numElts[j]++;
            }
            node.values.insert(refValue, idx);
          }
        }
        else
        {
          nodeCache[i] = node;
          node = node.up;
        }
      }
    }

    if(hasValueToInsert)
    {
      version(Verbose) numNodesCreated++;
      // adjust nodeCache for valueToInsert
      for(int j = 0; j < nodeCache.length; j++)
      {
        if(nodeCache[j] !is null)
        {
          if(nodeCache[j].right !is null && nodeCache[j].right.values.min() <= valueToInsert)
          {
            nodeCache[j]= nodeCache[j].right; 
          }
        }
        else
        {
          if(firstNodes[j] !is null && firstNodes[j].values.min() <= valueToInsert)
          {
            nodeCache[j] = firstNodes[j];
          }
        }
      }
      ulong s;
      while(s < maxDepth - 1 && uniform(0, invproba, r) == 0) s++;
      // element will be inserted in levels 0 ... s
      skipListNode!(T) prevNode, newNode;
      for(int i = 0; i <= s ; i++)
      {
        numElts[i]++;
        if (prevNode is null)
        {
          newNode = new skipListNode!(T)(numEltsPerNode, s);
          newNode.values.insert(valueToInsert, 0);
        }
        else 
        {
          newNode = new skipListNode!(T)(prevNode);
          newNode.up = prevNode;
        }
        assert(newNode.values.numValues > 0);
        if(nodeCache[i] is null) // insertion at the beginning of the list
        {
          newNode.right = firstNodes[i];
          firstNodes[i] = newNode;
        }
        else
        {
          skipListNode!(T) prevRightNeighbor = nodeCache[i].right;
          // nodeCache[i] right neighbor is newNode
          nodeCache[i].right = newNode;
          // newNode right neigbor is prevRightNeighbor
          newNode.right = prevRightNeighbor;
        }
        prevNode = newNode;
      }
    }
    return true;
  }
}

void skipListWithArraysUnitTest(uint numElts)
{
  writeln("\n**** Skip lists + arrays unit testing ****");
  int invproba = 6;
  int depth = 7;
  int arsize = 200;
  writeln("Creating a skip list + arrays of size ", arsize, " with proba 1/", invproba," and depth ", depth);
  skipListView!(uint) l = new skipListView!(uint)(invproba, depth, arsize, 3); 
 
  orderedSetInsertTest(l, numElts, false);
  l.displayCounts();
  l.check();
  l.printStats();

  orderedSetRemoveTest(l, numElts, false);
  l.displayCounts();
  l.check();
  l.printStats();
}

unittest{
  skipListWithArraysUnitTest(1000000);
}