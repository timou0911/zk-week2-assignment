//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { PoseidonT3 } from "./Poseidon.sol"; //an existing library to perform Poseidon hash on solidity
import "./verifier.sol"; //inherits with the MerkleTreeInclusionProof verifier contract

contract MerkleTree is Groth16Verifier {

    error MerkleTreeFull();

    uint256 constant LEAF_NUM = 8;
    uint256 constant NODE_NUM = 15;

    uint256[] public hashes; // the Merkle tree in flattened array form
    uint256 public index = 0; // the current index of the first unfilled leaf
    uint256 public root; // the current Merkle root

    constructor() {
        // [assignment] initialize a Merkle tree of 8 with blank leaves
        hashes = new uint256[](NODE_NUM);
        _update();
    }

    function insertLeaf(uint256 hashedLeaf) public returns (uint256) {
        // [assignment] insert a hashed leaf into the Merkle tree
        if (index >= LEAF_NUM) {
            revert MerkleTreeFull();
        }

        hashes[index] = hashedLeaf;
        index ++;
        _update();
        return root;
    }

    function verify(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[1] memory input
        ) public view returns (bool) {

        // [assignment] verify an inclusion proof and check that the proof root matches current root
        return verifyProof(a, b, c, input);
    }

    function _update() internal {
        for (uint256 i = 8; i < NODE_NUM; ++i) {
            uint256 left = 2*i-NODE_NUM-1;
            uint256 right = 2*i-NODE_NUM;
            hashes[i] = PoseidonT3.poseidon([hashes[left], hashes[right]]);
        }

        root = hashes[NODE_NUM-1];
    }
}
