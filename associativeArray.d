module associativeArray;

import std.stdio;

/** A thin wrapper around D built-in associative arrays. They are not ordered structures, but they are included 
    in the test to benchmark the other ordered structures 
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

import orderedSet;
class associativeArray(T): OrderedSet!(T)
{
	bool[T] internalAssoc;
	this(){}
	bool insert(T value)
	{
		bool found = internalAssoc.get(value, false);
		if(!found) internalAssoc[value] = true;
		return !found;
	}
	bool remove(T value){
		return internalAssoc.remove(value);
	}

	bool check(){return true;}
	void setDebugFlag(bool){}
}

void associativeArrayUnitTest(uint numElts)
{
	writeln("\n**** Associative array unit testing ****");
	writeln("Creating an associative array");
	auto t = new associativeArray!(uint)(); 
	orderedSetInsertTest(t, numElts, false);
	orderedSetRemoveTest(t, numElts, false);
}

unittest
{
	associativeArrayUnitTest(1000000);
}