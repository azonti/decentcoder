// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./ISubmission.sol";

interface ITester {
  function test(ISubmission submission) external view returns (bool passed);
}
