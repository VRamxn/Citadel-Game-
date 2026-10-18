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
    "internalType": "contract CitadelNFT"
   },
   {
    "name": "pilot_",
    "type": "address",
    "internalType": "contract PilotNFT"
   },
   {
    "name": "drakma_",
    "type": "address",
    "internalType": "contract Drakma"
   }
  ],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "CITADEL_PER_DRIP",
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
  "name": "DK_PER_DRIP",
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
  "name": "PILOT_PER_DRIP",
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
  "name": "citadel",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract CitadelNFT"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "drakma",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract Drakma"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "drip",
  "inputs": [],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "dripped",
  "inputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "address"
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
  "name": "grantCitadel",
  "inputs": [
   {
    "name": "to",
    "type": "address",
    "internalType": "address"
   },
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
  "name": "grantDrakma",
  "inputs": [
   {
    "name": "to",
    "type": "address",
    "internalType": "address"
   },
   {
    "name": "amount",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "grantPilot",
  "inputs": [
   {
    "name": "to",
    "type": "address",
    "internalType": "address"
   },
   {
    "name": "t",
    "type": "tuple",
    "internalType": "struct Traits.PilotTraits",
    "components": [
     {
      "name": "generation",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "subjugation",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "kult",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "level",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "sovereign",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "death",
      "type": "bool",
      "internalType": "bool"
     }
    ]
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "nextCitadel",
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
  "name": "pilot",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract PilotNFT"
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
  "type": "event",
  "name": "Dripped",
  "inputs": [
   {
    "name": "to",
    "type": "address",
    "indexed": true,
    "internalType": "address"
   },
   {
    "name": "citadels",
    "type": "uint256[]",
    "indexed": false,
    "internalType": "uint256[]"
   },
   {
    "name": "pilots",
    "type": "uint256[]",
    "indexed": false,
    "internalType": "uint256[]"
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
  "type": "error",
  "name": "AlreadyDripped",
  "inputs": []
 },
 {
  "type": "error",
  "name": "OutOfCitadel",
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
