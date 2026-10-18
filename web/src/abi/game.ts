export default [
 {
  "type": "function",
  "name": "BUILDINGS",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "FACTIONS",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "FLEET_TYPES",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "MAX_BUILDING_LEVEL",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "acceptOwnership",
  "inputs": [],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "aoState",
  "inputs": [
   {
    "name": "",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "uint8",
    "internalType": "enum GameStorage.AOState"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "buildingBaseCost",
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
    "type": "uint128",
    "internalType": "uint128"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "buildingBaseTime",
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
    "type": "uint32",
    "internalType": "uint32"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "citadelNft",
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
  "name": "drakma",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract IDrakma"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "epochOf",
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
    "type": "uint32",
    "internalType": "uint32"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "fleetPoints",
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
    "type": "uint128",
    "internalType": "uint128"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "fleetTypes",
  "inputs": [
   {
    "name": "",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "op",
    "type": "uint32",
    "internalType": "uint32"
   },
   {
    "name": "dp",
    "type": "uint32",
    "internalType": "uint32"
   },
   {
    "name": "carry",
    "type": "uint32",
    "internalType": "uint32"
   },
   {
    "name": "secsPerTile",
    "type": "uint32",
    "internalType": "uint32"
   },
   {
    "name": "trainSecs",
    "type": "uint32",
    "internalType": "uint32"
   },
   {
    "name": "academy",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "cost",
    "type": "uint128",
    "internalType": "uint128"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "install",
  "inputs": [
   {
    "name": "module",
    "type": "address",
    "internalType": "address"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "marchCount",
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
  "name": "mentatNft",
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
  "name": "moduleOf",
  "inputs": [
   {
    "name": "",
    "type": "bytes4",
    "internalType": "bytes4"
   }
  ],
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
  "name": "pendingOwner",
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
  "name": "pilotNft",
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
  "name": "pilotsMintedBy",
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
    "type": "uint16",
    "internalType": "uint16"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "radius",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "uint16",
    "internalType": "uint16"
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
  "name": "savedLevels",
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
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "season",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "uint32",
    "internalType": "uint32"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "siegeCount",
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
  "name": "techTree",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "address",
    "internalType": "contract ITechTree"
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
  "name": "treasury",
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
  "name": "walletScore",
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
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "event",
  "name": "ModuleInstalled",
  "inputs": [
   {
    "name": "module",
    "type": "address",
    "indexed": true,
    "internalType": "address"
   },
   {
    "name": "selectors",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "OwnershipTransferStarted",
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
 },
 {
  "type": "error",
  "name": "UnknownSelector",
  "inputs": [
   {
    "name": "selector",
    "type": "bytes4",
    "internalType": "bytes4"
   }
  ]
 },
 {
  "type": "function",
  "name": "attachMentat",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "mentatId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "build",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "building",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "claim",
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
  "type": "function",
  "name": "colonize",
  "inputs": [
   {
    "name": "pilotId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "ao",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "q",
    "type": "int16",
    "internalType": "int16"
   },
   {
    "name": "r",
    "type": "int16",
    "internalType": "int16"
   },
   {
    "name": "faction",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "outputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "hurryBuild",
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
  "type": "function",
  "name": "hurryTraining",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "fleetType",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "lite",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "ao",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "q",
    "type": "int16",
    "internalType": "int16"
   },
   {
    "name": "r",
    "type": "int16",
    "internalType": "int16"
   },
   {
    "name": "faction",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "research",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "pilotIds",
    "type": "uint256[]",
    "internalType": "uint256[]"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "mintPilot",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "pilotId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "setFaction",
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
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "setResearch",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "branch",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "train",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "fleetType",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "amount",
    "type": "uint64",
    "internalType": "uint64"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "unlite",
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
  "name": "AOStateChanged",
  "inputs": [
   {
    "name": "ao",
    "type": "uint8",
    "indexed": true,
    "internalType": "uint8"
   },
   {
    "name": "state",
    "type": "uint8",
    "indexed": false,
    "internalType": "enum GameStorage.AOState"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "BuildCompleted",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "building",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "level",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "BuildStarted",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "building",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "level",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "end",
    "type": "uint64",
    "indexed": false,
    "internalType": "uint64"
   },
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
  "type": "event",
  "name": "BuildingCostUpdated",
  "inputs": [
   {
    "name": "building",
    "type": "uint8",
    "indexed": true,
    "internalType": "uint8"
   },
   {
    "name": "cost",
    "type": "uint128",
    "indexed": false,
    "internalType": "uint128"
   },
   {
    "name": "time",
    "type": "uint32",
    "indexed": false,
    "internalType": "uint32"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "Claimed",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "to",
    "type": "address",
    "indexed": true,
    "internalType": "address"
   },
   {
    "name": "amount",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "Colonized",
  "inputs": [
   {
    "name": "citadelId",
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
    "name": "owner",
    "type": "address",
    "indexed": true,
    "internalType": "address"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "ConfigUpdated",
  "inputs": [
   {
    "name": "config",
    "type": "tuple",
    "indexed": false,
    "internalType": "struct GameStorage.Config",
    "components": [
     {
      "name": "baseDkPerDay",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "claimInterval",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "defectionWindow",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "resolverFeeBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "fortificationBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "maxPilots",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "distortion",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "siegeWaveSecs",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "siegeMinWaves",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "siegeAttritionBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "structureDp",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "colonizeCost",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "pilotFleetPoints",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "hurryBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "aoGapTiles",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "researchPerDay",
      "type": "uint128",
      "internalType": "uint128"
     }
    ]
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "FactionChanged",
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
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "FleetTypeUpdated",
  "inputs": [
   {
    "name": "fleetType",
    "type": "uint8",
    "indexed": true,
    "internalType": "uint8"
   },
   {
    "name": "stats",
    "type": "tuple",
    "indexed": false,
    "internalType": "struct GameStorage.FleetType",
    "components": [
     {
      "name": "op",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "dp",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "carry",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "secsPerTile",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "trainSecs",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "academy",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "cost",
      "type": "uint128",
      "internalType": "uint128"
     }
    ]
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "Hurried",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "what",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "index",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "price",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "Leveled",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "owner",
    "type": "address",
    "indexed": true,
    "internalType": "address"
   },
   {
    "name": "destroyed",
    "type": "bool",
    "indexed": false,
    "internalType": "bool"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "Lit",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "owner",
    "type": "address",
    "indexed": true,
    "internalType": "address"
   },
   {
    "name": "ao",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "q",
    "type": "int16",
    "indexed": false,
    "internalType": "int16"
   },
   {
    "name": "r",
    "type": "int16",
    "indexed": false,
    "internalType": "int16"
   },
   {
    "name": "faction",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "MarchSent",
  "inputs": [
   {
    "name": "marchId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "kind",
    "type": "uint8",
    "indexed": false,
    "internalType": "enum GameStorage.MarchKind"
   },
   {
    "name": "origin",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "target",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "arriveAt",
    "type": "uint64",
    "indexed": false,
    "internalType": "uint64"
   },
   {
    "name": "units",
    "type": "uint64[4]",
    "indexed": false,
    "internalType": "uint64[4]"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "MentatAttached",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "mentatId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "PilotMinted",
  "inputs": [
   {
    "name": "citadelId",
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
    "name": "generation",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "fleetPointsSpent",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "ResearchChanged",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
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
  "name": "SeasonStarted",
  "inputs": [
   {
    "name": "season",
    "type": "uint32",
    "indexed": true,
    "internalType": "uint32"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "TileBpsUpdated",
  "inputs": [
   {
    "name": "ao",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "q",
    "type": "int16",
    "indexed": false,
    "internalType": "int16"
   },
   {
    "name": "r",
    "type": "int16",
    "indexed": false,
    "internalType": "int16"
   },
   {
    "name": "bps",
    "type": "uint32",
    "indexed": false,
    "internalType": "uint32"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "TrainingQueued",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "fleetType",
    "type": "uint8",
    "indexed": false,
    "internalType": "uint8"
   },
   {
    "name": "amount",
    "type": "uint64",
    "indexed": false,
    "internalType": "uint64"
   },
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
  "type": "event",
  "name": "Unlit",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "owner",
    "type": "address",
    "indexed": true,
    "internalType": "address"
   },
   {
    "name": "paidOut",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   },
   {
    "name": "forfeited",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "error",
  "name": "AOClosed",
  "inputs": []
 },
 {
  "type": "error",
  "name": "BadConfig",
  "inputs": []
 },
 {
  "type": "error",
  "name": "BadFaction",
  "inputs": []
 },
 {
  "type": "error",
  "name": "BadFleetType",
  "inputs": []
 },
 {
  "type": "error",
  "name": "Busy",
  "inputs": []
 },
 {
  "type": "error",
  "name": "ClaimCooldown",
  "inputs": [
   {
    "name": "availableAt",
    "type": "uint64",
    "internalType": "uint64"
   }
  ]
 },
 {
  "type": "error",
  "name": "Engaged",
  "inputs": []
 },
 {
  "type": "error",
  "name": "HasMentat",
  "inputs": []
 },
 {
  "type": "error",
  "name": "Idle",
  "inputs": []
 },
 {
  "type": "error",
  "name": "MaxLevel",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NeedsAcademy",
  "inputs": [
   {
    "name": "level",
    "type": "uint8",
    "internalType": "uint8"
   }
  ]
 },
 {
  "type": "error",
  "name": "NeedsCitadelLevel",
  "inputs": [
   {
    "name": "level",
    "type": "uint8",
    "internalType": "uint8"
   }
  ]
 },
 {
  "type": "error",
  "name": "NeedsTech",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NoUnits",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NotCitadelOwner",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ]
 },
 {
  "type": "error",
  "name": "NotEnoughFleetPoints",
  "inputs": [
   {
    "name": "cost",
    "type": "uint256",
    "internalType": "uint256"
   }
  ]
 },
 {
  "type": "error",
  "name": "NotEnoughUnits",
  "inputs": [
   {
    "name": "fleetType",
    "type": "uint8",
    "internalType": "uint8"
   }
  ]
 },
 {
  "type": "error",
  "name": "NotFactionGrid",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NotLit",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ]
 },
 {
  "type": "error",
  "name": "NotPilotOwner",
  "inputs": []
 },
 {
  "type": "error",
  "name": "OffGrid",
  "inputs": []
 },
 {
  "type": "error",
  "name": "ReentrancyGuardReentrantCall",
  "inputs": []
 },
 {
  "type": "error",
  "name": "TileOccupied",
  "inputs": []
 },
 {
  "type": "error",
  "name": "TooManyPilots",
  "inputs": []
 },
 {
  "type": "error",
  "name": "Unreachable",
  "inputs": []
 },
 {
  "type": "function",
  "name": "joinSiege",
  "inputs": [
   {
    "name": "siegeId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "fromId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "units",
    "type": "uint64[4]",
    "internalType": "uint64[4]"
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
  "name": "raid",
  "inputs": [
   {
    "name": "fromId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "toId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "units",
    "type": "uint64[4]",
    "internalType": "uint64[4]"
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
  "name": "reinforce",
  "inputs": [
   {
    "name": "fromId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "toId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "units",
    "type": "uint64[4]",
    "internalType": "uint64[4]"
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
  "name": "resolve",
  "inputs": [
   {
    "name": "marchId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "scout",
  "inputs": [
   {
    "name": "fromId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "toId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "units",
    "type": "uint64[4]",
    "internalType": "uint64[4]"
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
  "name": "siege",
  "inputs": [
   {
    "name": "fromId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "toId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "units",
    "type": "uint64[4]",
    "internalType": "uint64[4]"
   },
   {
    "name": "pilot",
    "type": "uint256",
    "internalType": "uint256"
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
  "type": "event",
  "name": "Defected",
  "inputs": [
   {
    "name": "marchId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "attacker",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "defender",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "units",
    "type": "uint64[4]",
    "indexed": false,
    "internalType": "uint64[4]"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "MarchCompleted",
  "inputs": [
   {
    "name": "marchId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "MarchLost",
  "inputs": [
   {
    "name": "marchId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "RaidResolved",
  "inputs": [
   {
    "name": "marchId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "attacker",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "defender",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "attackerWon",
    "type": "bool",
    "indexed": false,
    "internalType": "bool"
   },
   {
    "name": "attackerLost",
    "type": "uint64[4]",
    "indexed": false,
    "internalType": "uint64[4]"
   },
   {
    "name": "defenderLost",
    "type": "uint64[4]",
    "indexed": false,
    "internalType": "uint64[4]"
   },
   {
    "name": "loot",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   },
   {
    "name": "resolverFee",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "Reinforced",
  "inputs": [
   {
    "name": "marchId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "origin",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "target",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "units",
    "type": "uint64[4]",
    "indexed": false,
    "internalType": "uint64[4]"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "ScoutReport",
  "inputs": [
   {
    "name": "marchId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "scout",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "target",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "success",
    "type": "bool",
    "indexed": false,
    "internalType": "bool"
   },
   {
    "name": "garrison",
    "type": "uint64[4]",
    "indexed": false,
    "internalType": "uint64[4]"
   },
   {
    "name": "vault",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   },
   {
    "name": "levels",
    "type": "uint8[6]",
    "indexed": false,
    "internalType": "uint8[6]"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "SiegeEnded",
  "inputs": [
   {
    "name": "siegeId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "success",
    "type": "bool",
    "indexed": false,
    "internalType": "bool"
   },
   {
    "name": "newCitadel",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "SiegeJoined",
  "inputs": [
   {
    "name": "siegeId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "units",
    "type": "uint64[4]",
    "indexed": false,
    "internalType": "uint64[4]"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "SiegeStarted",
  "inputs": [
   {
    "name": "siegeId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "attacker",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "target",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "pilot",
    "type": "uint256",
    "indexed": false,
    "internalType": "uint256"
   }
  ],
  "anonymous": false
 },
 {
  "type": "event",
  "name": "SiegeWave",
  "inputs": [
   {
    "name": "siegeId",
    "type": "uint256",
    "indexed": true,
    "internalType": "uint256"
   },
   {
    "name": "wave",
    "type": "uint32",
    "indexed": false,
    "internalType": "uint32"
   },
   {
    "name": "progress",
    "type": "int32",
    "indexed": false,
    "internalType": "int32"
   },
   {
    "name": "attackerLost",
    "type": "uint64[4]",
    "indexed": false,
    "internalType": "uint64[4]"
   },
   {
    "name": "defenderLost",
    "type": "uint64[4]",
    "indexed": false,
    "internalType": "uint64[4]"
   }
  ],
  "anonymous": false
 },
 {
  "type": "error",
  "name": "BadMarch",
  "inputs": []
 },
 {
  "type": "error",
  "name": "BadSiege",
  "inputs": []
 },
 {
  "type": "error",
  "name": "Besieged",
  "inputs": []
 },
 {
  "type": "error",
  "name": "NotArrived",
  "inputs": [
   {
    "name": "arriveAt",
    "type": "uint64",
    "internalType": "uint64"
   }
  ]
 },
 {
  "type": "error",
  "name": "NothingDue",
  "inputs": []
 },
 {
  "type": "error",
  "name": "SameCitadel",
  "inputs": []
 },
 {
  "type": "error",
  "name": "ScoutsOnly",
  "inputs": []
 },
 {
  "type": "error",
  "name": "SovereignProtected",
  "inputs": []
 },
 {
  "type": "function",
  "name": "advanceSiege",
  "inputs": [
   {
    "name": "siegeId",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "maxWaves",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "buildCost",
  "inputs": [
   {
    "name": "building",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "level",
    "type": "uint8",
    "internalType": "uint8"
   }
  ],
  "outputs": [
   {
    "name": "cost",
    "type": "uint256",
    "internalType": "uint256"
   },
   {
    "name": "time",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "citadel",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "c",
    "type": "tuple",
    "internalType": "struct GameStorage.Citadel",
    "components": [
     {
      "name": "owner",
      "type": "address",
      "internalType": "address"
     },
     {
      "name": "lit",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "doomRiot",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "ao",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "q",
      "type": "int16",
      "internalType": "int16"
     },
     {
      "name": "r",
      "type": "int16",
      "internalType": "int16"
     },
     {
      "name": "faction",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "research",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "generation",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "sekt",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "shield",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "engine",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "weapon",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "tech",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "lastSync",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "lastClaim",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "pilotOff",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "pilotDef",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "pilotMine",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "pilotHermetic",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "pilotScout",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "pilotResearch",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "incoming",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "outgoing",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "besieged",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "vault",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "mentat",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "levels",
      "type": "uint8[6]",
      "internalType": "uint8[6]"
     }
    ]
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "citadelAt",
  "inputs": [
   {
    "name": "ao",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "q",
    "type": "int16",
    "internalType": "int16"
   },
   {
    "name": "r",
    "type": "int16",
    "internalType": "int16"
   }
  ],
  "outputs": [
   {
    "name": "occupied",
    "type": "bool",
    "internalType": "bool"
   },
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "constructionOf",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "k",
    "type": "tuple",
    "internalType": "struct GameStorage.Construction",
    "components": [
     {
      "name": "building",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "level",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "start",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "end",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "cost",
      "type": "uint128",
      "internalType": "uint128"
     }
    ]
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "controllerOfCitadel",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
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
  "name": "controllerOfMentat",
  "inputs": [
   {
    "name": "mentatId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
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
  "name": "controllerOfPilot",
  "inputs": [
   {
    "name": "pilotId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
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
  "name": "garrisonOf",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "g",
    "type": "uint64[4]",
    "internalType": "uint64[4]"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "getConfig",
  "inputs": [],
  "outputs": [
   {
    "name": "",
    "type": "tuple",
    "internalType": "struct GameStorage.Config",
    "components": [
     {
      "name": "baseDkPerDay",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "claimInterval",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "defectionWindow",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "resolverFeeBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "fortificationBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "maxPilots",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "distortion",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "siegeWaveSecs",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "siegeMinWaves",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "siegeAttritionBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "structureDp",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "colonizeCost",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "pilotFleetPoints",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "hurryBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "aoGapTiles",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "researchPerDay",
      "type": "uint128",
      "internalType": "uint128"
     }
    ]
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "march",
  "inputs": [
   {
    "name": "marchId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "tuple",
    "internalType": "struct GameStorage.March",
    "components": [
     {
      "name": "kind",
      "type": "uint8",
      "internalType": "enum GameStorage.MarchKind"
     },
     {
      "name": "done",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "arriveAt",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "origin",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "target",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "originEpoch",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "targetEpoch",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "units",
      "type": "uint64[4]",
      "internalType": "uint64[4]"
     },
     {
      "name": "loot",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "sender",
      "type": "address",
      "internalType": "address"
     },
     {
      "name": "pilot",
      "type": "uint256",
      "internalType": "uint256"
     }
    ]
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "miningRate",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
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
  "name": "pilotMintCost",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
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
  "name": "pilotsOf",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "uint256[]",
    "internalType": "uint256[]"
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "placement",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "bool",
    "internalType": "bool"
   },
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
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "researchRate",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
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
  "name": "setAOState",
  "inputs": [
   {
    "name": "ao",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "state",
    "type": "uint8",
    "internalType": "enum GameStorage.AOState"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "setBuildingCost",
  "inputs": [
   {
    "name": "building",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "cost",
    "type": "uint128",
    "internalType": "uint128"
   },
   {
    "name": "time",
    "type": "uint32",
    "internalType": "uint32"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "setConfig",
  "inputs": [
   {
    "name": "c",
    "type": "tuple",
    "internalType": "struct GameStorage.Config",
    "components": [
     {
      "name": "baseDkPerDay",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "claimInterval",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "defectionWindow",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "resolverFeeBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "fortificationBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "maxPilots",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "distortion",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "siegeWaveSecs",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "siegeMinWaves",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "siegeAttritionBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "structureDp",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "colonizeCost",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "pilotFleetPoints",
      "type": "uint128",
      "internalType": "uint128"
     },
     {
      "name": "hurryBps",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "aoGapTiles",
      "type": "uint16",
      "internalType": "uint16"
     },
     {
      "name": "researchPerDay",
      "type": "uint128",
      "internalType": "uint128"
     }
    ]
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "setFleetType",
  "inputs": [
   {
    "name": "fleetType",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "f",
    "type": "tuple",
    "internalType": "struct GameStorage.FleetType",
    "components": [
     {
      "name": "op",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "dp",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "carry",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "secsPerTile",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "trainSecs",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "academy",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "cost",
      "type": "uint128",
      "internalType": "uint128"
     }
    ]
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "setTileBps",
  "inputs": [
   {
    "name": "ao",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "q",
    "type": "int16",
    "internalType": "int16"
   },
   {
    "name": "r",
    "type": "int16",
    "internalType": "int16"
   },
   {
    "name": "bps",
    "type": "uint32",
    "internalType": "uint32"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "setTreasury",
  "inputs": [
   {
    "name": "treasury_",
    "type": "address",
    "internalType": "address"
   }
  ],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "siegeOf",
  "inputs": [
   {
    "name": "siegeId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "tuple",
    "internalType": "struct GameStorage.Siege",
    "components": [
     {
      "name": "active",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "attacker",
      "type": "address",
      "internalType": "address"
     },
     {
      "name": "faction",
      "type": "uint8",
      "internalType": "uint8"
     },
     {
      "name": "origin",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "target",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "originEpoch",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "targetEpoch",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "pilot",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "start",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "waves",
      "type": "uint32",
      "internalType": "uint32"
     },
     {
      "name": "progress",
      "type": "int32",
      "internalType": "int32"
     },
     {
      "name": "units",
      "type": "uint64[4]",
      "internalType": "uint64[4]"
     }
    ]
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "startSeason",
  "inputs": [],
  "outputs": [],
  "stateMutability": "nonpayable"
 },
 {
  "type": "function",
  "name": "statsOf",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "tuple",
    "internalType": "struct GameBase.Stats",
    "components": [
     {
      "name": "mineBps",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "offBps",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "defBps",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "fortBps",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "repairBps",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "siegeDefBps",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "scoutBps",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "structure",
      "type": "uint256",
      "internalType": "uint256"
     },
     {
      "name": "typeOff",
      "type": "uint256[4]",
      "internalType": "uint256[4]"
     },
     {
      "name": "typeDef",
      "type": "uint256[4]",
      "internalType": "uint256[4]"
     },
     {
      "name": "speedBps",
      "type": "uint256[4]",
      "internalType": "uint256[4]"
     },
     {
      "name": "trainBps",
      "type": "uint256[4]",
      "internalType": "uint256[4]"
     },
     {
      "name": "veerdacht",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "deiIudicium",
      "type": "bool",
      "internalType": "bool"
     },
     {
      "name": "dalaa",
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
  "name": "tileBps",
  "inputs": [
   {
    "name": "ao",
    "type": "uint8",
    "internalType": "uint8"
   },
   {
    "name": "q",
    "type": "int16",
    "internalType": "int16"
   },
   {
    "name": "r",
    "type": "int16",
    "internalType": "int16"
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
  "name": "trainingOf",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
   }
  ],
  "outputs": [
   {
    "name": "",
    "type": "tuple[4]",
    "internalType": "struct GameStorage.Batch[4]",
    "components": [
     {
      "name": "total",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "done",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "start",
      "type": "uint64",
      "internalType": "uint64"
     },
     {
      "name": "unitSecs",
      "type": "uint32",
      "internalType": "uint32"
     }
    ]
   }
  ],
  "stateMutability": "view"
 },
 {
  "type": "function",
  "name": "vaultOf",
  "inputs": [
   {
    "name": "citadelId",
    "type": "uint256",
    "internalType": "uint256"
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
  "name": "walletLevel",
  "inputs": [
   {
    "name": "wallet",
    "type": "address",
    "internalType": "address"
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
 }
] as const;
