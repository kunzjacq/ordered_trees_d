module avl;

/* 
 * Implementation of Adelson-Velskii and Landis' (AVL) trees, a class of (rather tightly) self-rebalancing trees. 
 * see http://en.wikipedia.org/wiki/AVL_tree.
 * AVL trees are implemented through two templated classes depending on the types of the stored values, which 
 * must be totally ordered: 
 * avlNode!(T), the node class;
 * avlTree!(T), the tree class, which holds the root avlNode of a tree.
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
 
import std.algorithm;
import std.stdio;
import std.math;
import std.random;
import std.datetime;
import core.exception;

import orderedSet;

//version = Verbose;
// uncomment to print actions of rebalancing

enum direction{left=0, right=1};

class avlNode(T)
{
  T value;
  int depth;
  avlNode!(T) left;
  avlNode!(T) right;
  this(T val)
  {
    value = val;
  }

  ref avlNode!(T) subNode(direction d)
  {
    if(d == direction.left) return left;
    else return right;
  }
  ref avlNode!(T) oppositeNode(direction d)
  {
    if(d == direction.left) return right;
    else return left;
  }
  int leftDepth() const 
  {
    return left is null? -1 : left.depth;
  }
  int rightDepth() const
  {
    return right is null? -1 : right.depth;
  }
  void updateDepth()
  {
    depth = 1 + max(leftDepth(),rightDepth());
  }

  void recursiveUpdateDepth()
  {
    if(left !is null) left.recursiveUpdateDepth();
    if(right !is null) right.recursiveUpdateDepth();
    depth = 1 + max(leftDepth(),rightDepth());
  }

  bool recursiveCheckDepth()
  {
    try{
      recursiveCheckDepthAux();
    }
    catch(AssertError e)
    {
      return false;
    }
    return true;
  }

  void recursiveCheckDepthAux()
  {
    if(left !is null) left.recursiveCheckDepthAux();
    if(right !is null) right.recursiveCheckDepthAux();
    assert(depth == 1 + max(leftDepth(),rightDepth()));
  }

  bool recursiveCheckBalance()
  {
    try{
      recursiveCheckBalanceAux();
    }
    catch(AssertError e)
    {
      return false;
    }
    return true;
  }

  void recursiveCheckBalanceAux()
  {
    if(left !is null) left.recursiveCheckBalanceAux();
    if(right !is null) right.recursiveCheckBalanceAux();
    assert(abs(leftDepth()-rightDepth())<=1);
  }

  bool recursiveCheckKeyOrder()
  {
    T a,b;
    try{
      recursiveCheckKeyOrderAux(a, b);
    }
    catch(AssertError e)
    {
      return false;
    }
    return true;
  }


  void recursiveCheckKeyOrderAux(out T  minValue, out T  maxValue)
  {
    minValue = value;
    maxValue = value;
    if(left !is null)
    {
      T v;
      left.recursiveCheckKeyOrderAux(minValue, v);
      assert(value > v);
    }
    if(right !is null)
    {
      T v;
      right.recursiveCheckKeyOrderAux(v, maxValue);
      assert(value < v);
    }
  }


  void append(avlNode!(T) node, direction d)
  {
    if(d == direction.left) left = node;
    else right = node;
  }

  /* The two fundamental transforms of AVL trees 
   */
  static void rotate(direction d, ref avlNode!(T) anchor)
  {
    auto oldRoot = anchor;
    // make oldRoot.oppositeNode(d) the new root node
    auto newRoot = oldRoot.oppositeNode(d);
    oldRoot.oppositeNode(d) = newRoot.subNode(d);
    newRoot.subNode(d) = oldRoot;
    oldRoot.updateDepth();
    newRoot.updateDepth();
    anchor = newRoot;
  }

  static void rotate2(direction d, ref avlNode!(T) anchor)
  {
    auto A = anchor;
    auto B = A.oppositeNode(d);
    auto newRoot = B.subNode(d);
    auto newRoots1 = newRoot.subNode(d);
    auto newRoots2 = newRoot.oppositeNode(d);
    A.oppositeNode(d) = newRoots1;
    newRoot.subNode(d) = A;
    B.subNode(d) = newRoots2;
    newRoot.oppositeNode(d) = B;
    A.updateDepth();
    B.updateDepth();
    newRoot.updateDepth();
    anchor = newRoot;
  }

  /* Recursively insert element 'valToInsert' in the AVL tree of root 'anchor', then rebalance if required.
   * returns height change resulting from the insertion.
   * 'anchor' may be changed by the function because of rebalancing, this is why this function is not a 
   * class member function operating on 'this' instead of 'anchor'.
   */
  static int recursiveInsert(T valToInsert, ref avlNode!(T) anchor, ref bool inserted)
  {
    int oldDepth = anchor.depth;
    int depthChange = 0;
    if(valToInsert == anchor.value) 
    {
      inserted = false;
      return 0;
    }
    else if(valToInsert > anchor.value)
    {
      if(anchor.right is null)
      {
        anchor.right = new avlNode!(T)(valToInsert);
        depthChange = 1;
        inserted = true;
      }
      else
      {
        depthChange = recursiveInsert(valToInsert, anchor.right, inserted);
      }
    }
    else // valToInsert < value
    {
      if(anchor.left is null)
      {
        anchor.left = new avlNode!(T)(valToInsert);
        inserted = true;
        depthChange = 1;
      }
      else
      {
        depthChange = recursiveInsert(valToInsert, anchor.left, inserted);
      }
    }
    // Rebalance if needed, update depth and propagate depth variation.
    // 'depthchange' is the depth change in the subtree where the insertion was made.
    // If depthchange == 0, none of the subtrees depth changed, the tree is still balanced.
    // if it is !=0, we may need to rebalance and to recompute the depth and depth change at the current level.
    if(depthChange != 0)
    {
      depthChange = rebalance(anchor, oldDepth);
    }
    return depthChange;
  }

  /* finds and deletes the leftmost element (if 'd' = left) or the rightmost element (if 'd' = right) 
   * in tree starting at 'anchor'. the value of the deleted node is returned in 'deletedValue', and the 
   * tree depth change is returned */
  static int findAndDeleteMinMax(direction d, ref avlNode!(T) anchor, ref T deletedValue)
  {
    immutable int oldDepth = anchor.depth;
    if(anchor.subNode(d) is null)
    {
      deletedValue = anchor.value;
      anchor = anchor.oppositeNode(d);
      return -1;
    }
    else
    {
      immutable int oldSubDepth = anchor.subNode(d).depth;
      int subDepthChange = findAndDeleteMinMax(d, anchor.subNode(d), deletedValue);
      anchor.updateDepth();
      int newSubDepth = (anchor.subNode(d) is null ? -1 : anchor.subNode(d).depth);
      assert(newSubDepth - oldSubDepth == subDepthChange);
      int depthChange;
      if(subDepthChange != 0)
      {
        depthChange = anchor.depth - oldDepth;
        assert(depthChange <= 0 && depthChange >= -1);
        depthChange = rebalance(anchor, oldDepth);
        assert(depthChange <= 0 && depthChange >= -1);
      }
      return depthChange;
    }
  }

  /* removes 'valToRemove' from the tree of root 'anchor' if present. Otherwise does nothing. 
   * returns height change resulting from the delete. 'anchor' may be modified in the process. */
  static int recursiveRemove(T valToRemove, ref avlNode!(T) anchor, ref bool removed)
  {
    immutable int oldDepth = anchor.depth;
    int subDepthChange;
    if(valToRemove == anchor.value){
      removed = true;
      if(anchor.left is null && anchor.right is null)
      {
        anchor = null;
        return -1;
      }
      else if(anchor.left is null || anchor.right is null)
      {
        anchor = (anchor.left is null)? anchor.right : anchor.left;
        return -1;
      }
      else
      {
        if(anchor.right.depth >= anchor.left.depth)
        {
          subDepthChange = findAndDeleteMinMax(direction.left, anchor.right, anchor.value);
        }
        else
        {
          subDepthChange = findAndDeleteMinMax(direction.right, anchor.left, anchor.value);
        }
      }
    }
    else if(valToRemove > anchor.value)
    {
      if(anchor.right !is null) 
      {
        subDepthChange = recursiveRemove(valToRemove, anchor.right, removed);
      }
    }
    else // valToRemove < value
    {
      if(anchor.left !is null)
      {
        subDepthChange = recursiveRemove(valToRemove, anchor.left, removed);
      }
    }
    // rebalance if needed, update depth and propagate depth variation
    int depthChange;
    if(subDepthChange != 0)
    {
      depthChange = rebalance(anchor, oldDepth);
    }
    return depthChange;
  }

  static int rebalance(ref avlNode!(T) anchor, int oldDepth)
  {
    immutable int depthDiff = anchor.rightDepth() - anchor.leftDepth();
    assert(abs(depthDiff) <= 2);
    version(Verbose)
    {
      writeln("before rebalance: ");
      writeln("root: ", anchor.value);
      writeln("left depth ", anchor.leftDepth());
      writeln("right depth ", anchor.rightDepth());
      if(anchor.left !is null) anchor.left.print();
      writeln();
      if(anchor.right !is null) anchor.right.print();
      writeln();
    }
    if(depthDiff > 1)
    {
      if(anchor.right !is null && anchor.right.leftDepth() - anchor.right.rightDepth() == 1)
      {
        rotate2(direction.left, anchor);
      } 
      else 
      {
        rotate(direction.left, anchor);
      }
    }
    else if(depthDiff < -1)
    {
      if(anchor.left !is null && anchor.left.rightDepth() - anchor.left.leftDepth() == 1)
      {
        rotate2(direction.right, anchor);
      }
      else
      {
        rotate(direction.right, anchor);
      }
    }
    version(Verbose)
    {
      writeln("after rebalance: ");
      writeln("root: ", anchor.value);
      writeln("left depth ", anchor.leftDepth());
      writeln("right depth ", anchor.rightDepth());
      if(anchor.left !is null) anchor.left.print();
      writeln();
      if(anchor.right !is null) anchor.right.print();
      writeln();
    }

    debug
    {
      // recompute depthdiff after rebalancing and ensure that it is now balanced
      int depthDiff2 = anchor.rightDepth() - anchor.leftDepth();
      assert(abs(depthDiff2) <= 1);
    }
    anchor.updateDepth();
    int depthChange = anchor.depth - oldDepth;
    return depthChange;
  }

  void print()
  {
    write("([", depth,"] ", value);
    if(left !is null || right !is null) 
    {
      write(" ");
      if(left is null)  write("()");
      else left.print();
      write(",");
      if(right is null) write("()");
      else right.print();
    }
    write(")");
  }
}

class avlTree(T): OrderedSet!(T)
{
  avlNode!(T) rootNode;
  bool debugFlag;

  bool check()
  {
    return 
      rootNode.recursiveCheckDepth() &&
      rootNode.recursiveCheckBalance() &&
      rootNode.recursiveCheckKeyOrder();
  }

  void rotate(direction d)
  {
    avlNode!(T).rotate(d, rootNode);
  }

  void append(avlTree!(T) t, direction d)
  {
    rootNode.append(t.rootNode, d);
  }

  void append(avlNode!(T) n, direction d)
  {
    rootNode.append(n, d);
  }

  void print()
  {
    rootNode.print();
    writeln();
  }

  bool insert(T valToInsert)
  {
    bool inserted = false;
    if(rootNode is null)
    {
      rootNode = new avlNode!(T)(valToInsert);
      inserted = true;
    }
    else
    {
      avlNode!(T).recursiveInsert(valToInsert, rootNode, inserted);
    }
    return inserted;
  }
 
  bool remove(T valToRemove)
  {
    bool removed = false;
    if(rootNode !is null)
    {
    avlNode!(T).recursiveRemove(valToRemove, rootNode, removed);
    }
    return removed;
  }

  void setDebugFlag(bool p_flag)
  {
    debugFlag = p_flag;
  }
}


void avlTreeUnitTest1()
{
  writeln("creating tree");
  avlTree!(int) t = new avlTree!(int);
  t.rootNode = new avlNode!(int)(4);

  auto tl = new avlNode!(int)(2);
  auto tll = new avlNode!(int)(1);
  auto tlr = new avlNode!(int)(3);
  auto tr = new avlNode!(int)(6);
  auto trl = new avlNode!(int)(5);
  auto trr = new avlNode!(int)(7);

  tl.append(tll, direction.left);
  tl.append(tlr, direction.right);
  tr.append(trl, direction.left);
  tr.append(trr, direction.right);
  t.append(tl, direction.left);
  t.append(tr, direction.right);
  t.rootNode.recursiveUpdateDepth();

  writeln("Before rotation: ");
  t.print();

  t.rotate(direction.left);
  writeln("After left rotation: ");
  t.print();

  t.rotate(direction.right);
  writeln("After right rotation: ");
  t.print();
}

void avlTreeUnitTest2(uint numElts)
{
  writeln("\n**** AVL trees unit testing ****");
  writeln("Creating AVL tree");
  avlTree!(uint) t = new avlTree!(uint);
  t.rootNode = new avlNode!(uint)(4);
  orderedSetInsertTest(t, numElts, false);
  if(!t.check()) writeln("Structural check failed!");
  orderedSetRemoveTest(t, numElts, false);
  if(!t.check()) writeln("Structural check failed!");
}

unittest{
  writeln("**** AVL trees unit testing ****");
  avlTreeUnitTest1();
  avlTreeUnitTest2();
}
