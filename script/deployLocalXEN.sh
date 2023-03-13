#!/bin/sh

echo "🧑🏾‍💻 Deploy XEN"

forge script ./script/XENLocal.s.sol:XENLocalScript --fork-url http://localhost:8545 --broadcast