// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

interface ICorrectness {
  function input1() external pure returns (bytes memory _input1);
  function input2() external pure returns (bytes memory _input2);
  function input3() external pure returns (bytes memory _input3);
  function isOutput1Correct(bytes memory output1) external pure returns (bool);
  function isOutput2Correct(bytes memory output2) external pure returns (bool);
  function isOutput3Correct(bytes memory output3) external pure returns (bool);
  function gasLimit() external pure returns (uint);
}
