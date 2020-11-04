// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

interface ISubmission {
  function main(bytes memory input) external pure returns (bytes memory output);
}
