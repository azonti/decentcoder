// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./ISubmission.sol";

interface ITester {
  function test(ISubmission submission) external pure returns (bool passed);
}
