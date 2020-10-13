// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

interface ITester {
  function test(bytes memory submissionCC) external view returns (bool passed);
}
