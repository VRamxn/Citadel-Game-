export default [
 {
  "type": "constructor",
  "inputs": [
   {
    "name": "citadel_",
    "type": "address",
    "internalType": "contract MockOriginal"
   },
   {
    "name": "pilot_",
    "type": "address",
    "internalType": "contract MockOriginal"
   }
  ],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "citadel",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract MockOriginal"
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
  "name": "nextPilot",
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
  "name": "pilot",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract MockOriginal"
   }
  ],
  "stateMutability": "view"
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
    "type": "uint256[2]",
    "indexed": false,
    "internalType": "uint256[2]"
   },
   {
    "name": "pilots",
    "type": "uint256[2]",
    "indexed": false,
    "internalType": "uint256[2]"
   }
  ],
  "anonymous": false
 },
 {
  "type": "error",
  "name": "AlreadyDripped",
  "inputs": []
 }
] as const;
