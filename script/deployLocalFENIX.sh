#!/bin/sh

echo "🧑🏾‍💻 Deploy FENIX"

forge script ./script/FENIXLocal.s.sol:FENIXLocalScript --fork-url http://localhost:8545 --broadcast