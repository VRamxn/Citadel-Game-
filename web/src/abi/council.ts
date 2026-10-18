export default [
 {
  "type": "constructor",
  "inputs": [
   {
    "name": "pilot_",
    "type": "address",
    "internalType": "contract IPilotNFT"
   },
   {
    "name": "game_",
    "type": "address",
    "internalType": "contract IGameView"
   },
   {
    "name": "technocracy_",
    "type": "address",
    "internalType": "contract ISovereignCount"
   }
  ],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "VOTING_PERIOD",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "execute",
  "inputs": [
   {
    "name": "id",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "game",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract IGameView"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "passed",
  "inputs": [
   {
    "name": "id",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "bool",
    "internalType": "bool"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "pilot",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract IPilotNFT"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "proposal",
  "inputs": [
   {
    "name": "id",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "tuple",
    "internalType": "struct SovereignCouncil.Proposal",
    "components": [
     {
      "name": "proposer",
      "type": "address",
      "internalType": "address"
     },
     {
      "name": "target",
      "type": "address",
      "internalType": "address"
     },
     {
      "name": "data",
      "type": "bytes",
      "internalType": "bytes"
     },
     {
      "name": "description",
      "type": "string",
      "internalType": "string"
     },
     {
      "name": "deadline",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "seats",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "yes",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "no",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "executed",
      "type": "bool",
      "internalType": "bool"
     }
    ]
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "proposalCount",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "propose",
  "inputs": [
   {
    "name": "pilotId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "target",
    "type": "address",
    "internalType": "address"
   },
   {
    "name": "data",
    "type": "bytes",
    "internalType": "bytes"
   },
   {
    "name": "description",
    "type": "string",
    "internalType": "string"
   }
  ],
  "outputs": [
   {
    "name": "id",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "technocracy",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract ISovereignCount"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "vote",
  "inputs": [
   {
    "name": "id",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "pilotId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "support",
    "type": "bool",
    "internalType": "bool"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "voted",
  "inputs": [
   {
    "name": "",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "bool",
    "internalType": "bool"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "event",
  "name": "Executed",
  "inputs": [
   {
    "name": "id",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "Proposed",
  "inputs": [
   {
    "name": "id",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "pilotId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "target",
    "type": "address",
    "indexed": false,
    "internalType": "address"
   },
   {
    "name": "data",
    "type": "bytes",
    "indexed": false,
    "internalType": "bytes"
   },
   {
    "name": "description",
    "type": "string",
    "indexed": false,
    "internalType": "string"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "Voted",
  "inputs": [
   {
    "name": "id",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "pilotId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "support",
    "type": "bool",
    "indexed": false,
    "internalType": "bool"
   }
  ],
  "anonymous": false
 },
 {
  "type": "error",
  "name": "AlreadyVoted",
  "inputs": []
 },
 {
  "type": "error",
  "name": "CallFailed",
  "inputs": [
   {
    "name": "reason",
    "type": "bytes",
    "internalType": "bytes"
   }
  ]
 },
 {
  "type": "error",
  "name": "Closed",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NotPassed",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NotSovereign",
  "inputs": []
 }
] as const;
