module.exports = [
  {
    payable: true,
    stateMutability: "payable",
    type: "fallback",
  },
  {
    constant: true,
    inputs: [],
    name: "getAddressETH",
    outputs: [
      {
        internalType: "address",
        name: "eth",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "pure",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "getAddressKyber",
    outputs: [
      {
        internalType: "address",
        name: "kyber",
        type: "address",
      },
    ],
    payable: false,
    stateMutability: "pure",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "address",
        name: "src",
        type: "address",
      },
      {
        internalType: "address",
        name: "_owner",
        type: "address",
      },
    ],
    name: "getBal",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        internalType: "address",
        name: "src",
        type: "address",
      },
      {
        internalType: "address",
        name: "dest",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "srcAmt",
        type: "uint256",
      },
    ],
    name: "getExpectedRate",
    outputs: [
      {
        internalType: "uint256",
        name: "expectedRate",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
];
