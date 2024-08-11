// //SPDX-License-Identifier: Unlicense
// pragma solidity ^0.8.0;

// import { PoseidonT3 } from "./Poseidon.sol"; //an existing library to perform Poseidon hash on solidity
// import "./verifier.sol"; //inherits with the MerkleTreeInclusionProof verifier contract

// contract MerkleTree is Groth16Verifier {

//     error MerkleTreeFull();

//     uint256 constant LEAF_NUM = 8;
//     uint256 constant NODE_NUM = LEAF_NUM * 2 - 1;

//     uint256[] public hashes; // the Merkle tree in flattened array form
//     uint256 public index = 0; // the current index of the first unfilled leaf
//     uint256 public root; // the current Merkle root

//     constructor() {
//         // [assignment] initialize a Merkle tree of 8 with blank leaves
//         hashes = new uint256[](NODE_NUM);
//         _update();
//     }

//     function insertLeaf(uint256 hashedLeaf) public returns (uint256) {
//         // [assignment] insert a hashed leaf into the Merkle tree
//         if (index >= LEAF_NUM) {
//             revert MerkleTreeFull();
//         }

//         hashes[index] = hashedLeaf;
//         ++ index;
//         _update();
//         return root;
//     }

//     function verify(
//             uint[2] calldata a,
//             uint[2][2] calldata b,
//             uint[2] calldata c,
//             uint[1] calldata input
//         ) public view returns (bool) {

//         // [assignment] verify an inclusion proof and check that the proof root matches current root
//         return verifyProof(a, b, c, input);
//     }

//     function _update() internal {
//         for (uint256 i = 8; i < NODE_NUM; ++i) {
//             uint256 left = 2 * i - NODE_NUM - 1;
//             uint256 right = 2 * i - NODE_NUM;
//             hashes[i] = PoseidonT3.poseidon([hashes[left], hashes[right]]);
//         }

//         root = hashes[NODE_NUM-1];
//     }
// }

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { PoseidonT3 } from "./Poseidon.sol"; //an existing library to perform Poseidon hash on solidity
import "./verifier.sol"; //inherits with the MerkleTreeInclusionProof verifier contract

contract MerkleTree is Groth16Verifier {
    uint256[] public hashes; // the Merkle tree in flattened array form
    uint256 public index = 0; // the current index of the first unfilled leaf
    uint256 public root; // the current Merkle root

    /*
    =====relation between father node and child node=====
    the bottom left node start from 0

    father: f
    child: c
    childleft: c1
    childright: c2
    number of total node: T

    f=(T+c+1)/2
    c1=2f-T-1
    c2=2f-T
    */

    constructor() {
        // [assignment] initialize a Merkle tree of 8 with blank leaves
        uint num_leaves = 8;
        uint total_node=2**(3+1)-1;
        hashes= new uint256[](total_node);
        
        // init leave hash
        for (uint i=0; i<num_leaves;i++){
            hashes[i]=0;
        }

        //calculate hash value of internal node
        for (uint i=num_leaves;i<total_node;i++){
            hashes[i]=PoseidonT3.poseidon([hashes[2*i-total_node-1],hashes[2*i-total_node]]);
        }

        root=hashes[hashes.length - 1];

    }

    function insertLeaf(uint256 hashedLeaf) public returns (uint256) {
        // [assignment] insert a hashed leaf into the Merkle tree
        require(index < 8, "Merkle tree is full");

        hashes[index]=hashedLeaf;
        uint total_node=2**(3+1)-1;
        uint current_index=index;

        //update each node on the path to the root
        do{
            //find father node
            current_index=(total_node+current_index+1)/2;
            
            hashes[current_index]=PoseidonT3.poseidon([hashes[2*current_index-total_node-1],hashes[2*current_index-total_node]]);
        }while(current_index<total_node-1);

        root = hashes[hashes.length - 1];
        index++;
        return root;


    }

    function verify(
            uint[2] calldata a,
            uint[2][2] calldata b,
            uint[2] calldata c,
            uint[1] calldata input
        ) public view returns (bool) {

        // [assignment] verify an inclusion proof and check that the proof root matches current root
        require(input[0] == root, "Proof root does not match current root");
        return verifyProof(a, b, c, input);
    
    }
}