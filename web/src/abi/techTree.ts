export default [
 {
  "type": "constructor",
  "inputs": [
   {
    "name": "owner_",
    "type": "address",
    "internalType": "address"
   },
   {
    "name": "citadel_",
    "type": "address",
    "internalType": "contract ICitadelNFT"
   },
   {
    "name": "mentat_",
    "type": "address",
    "internalType": "contract IMentatNFT"
   }
  ],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "bits",
  "inputs": [
   {
    "name": "faction",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "outputs": [
   {
    "name": "b",
    "type": "uint64",
    "internalType": "uint64"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "branchMentatClaimed",
  "inputs": [
   {
    "name": "",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "",
    "type": "uint8",
    "internalType": "uint8"
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
  "name": "citadel",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract ICitadelNFT"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "claimBranchMentat",
  "inputs": [
   {
    "name": "branch",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "relikId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "mentatId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "claimRelikMentat",
  "inputs": [
   {
    "name": "relikId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "mentatId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
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
    "internalType": "address"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "mentat",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract IMentatNFT"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "nextCost",
  "inputs": [
   {
    "name": "faction",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "branch",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
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
  "name": "owner",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "address"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "pool",
  "inputs": [
   {
    "name": "faction",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "branch",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "outputs": [
   {
    "name": "points",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "ratePerDay",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "keys",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "completed",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "register",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "faction",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "branch",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "ratePerDay",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "key",
    "type": "bool",
    "internalType": "bool"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "registrationOf",
  "inputs": [
   {
    "name": "",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "active",
    "type": "bool",
    "internalType": "bool"
   },
   {
    "name": "faction",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "branch",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "key",
    "type": "bool",
    "internalType": "bool"
   },
   {
    "name": "ratePerDay",
    "type": "uint128",
    "internalType": "uint128"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "relikMentatClaimed",
  "inputs": [
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
  "type": "function",
  "name": "renounceOwnership",
  "inputs": [],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "setGame",
  "inputs": [
   {
    "name": "game_",
    "type": "address",
    "internalType": "address"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "setTechBaseCost",
  "inputs": [
   {
    "name": "cost",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "techBaseCost",
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
  "name": "transferOwnership",
  "inputs": [
   {
    "name": "newOwner",
    "type": "address",
    "internalType": "address"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "unregister",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "event",
  "name": "MentatClaimed",
  "inputs": [
   {
    "name": "mentatId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "relikId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "faction",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "branch",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "OwnershipTransferred",
  "inputs": [
   {
    "name": "previousOwner",
    "type": "address",
    "indexed": true,
    "internalType": "address"
   },
   {
    "name": "newOwner",
    "type": "address",
    "indexed": true,
    "internalType": "address"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "Registered",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "faction",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "branch",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "ratePerDay",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   },
   {
    "name": "key",
    "type": "bool",
    "indexed": false,
    "internalType": "bool"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "TechBaseCostUpdated",
  "inputs": [
   {
    "name": "cost",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "error",
  "name": "AlreadyClaimed",
  "inputs": []
 },
 {
  "type": "error",
  "name": "BranchIncomplete",
  "inputs": []
 },
 {
  "type": "error",
  "name": "GameSet",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NotController",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NotKey",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NotRelik",
  "inputs": []
 },
 {
  "type": "error",
  "name": "OnlyGame",
  "inputs": []
 },
 {
  "type": "error",
  "name": "OwnableInvalidOwner",
  "inputs": [
   {
    "name": "owner",
    "type": "address",
    "internalType": "address"
   }
  ]
 },
 {
  "type": "error",
  "name": "OwnableUnauthorizedAccount",
  "inputs": [
   {
    "name": "account",
    "type": "address",
    "internalType": "address"
   }
  ]
 }
] as const;
