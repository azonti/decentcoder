// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

interface IAnswer {
  function answer(bytes memory input) external pure returns (bytes memory output);
}
