// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./ICorrectness.sol";
import "./IAnswer.sol";

library ContestsLibrary {
  function isRCPureAndStandalone(address a) external view returns (bool) {
    uint rcSize;
    assembly { rcSize := extcodesize(a) }
    bytes memory rc = new bytes(rcSize);
    assembly { extcodecopy(a, add(rc, 0x20), 0, rcSize) }

    bool maybeCode = true; bool maybeNonPureOrNonStandalone;
    for(uint i = 0; i < rcSize; i++) {
      if (uint8(rc[i]) >= 0x60 && uint8(rc[i]) <= 0x7f) {
        i += uint8(rc[i]) - 0x5f;
      } else if (maybeCode) {
        if (maybeNonPureOrNonStandalone && (uint8(rc[i]) == 0x00 || uint8(rc[i]) == 0x56 || uint8(rc[i]) == 0x57 || uint8(rc[i]) == 0xf3)) {
          return false;
        } else if ((uint8(rc[i]) >= 0x30 && uint8(rc[i]) <= 0x33) || (uint8(rc[i]) >= 0x3a && uint8(rc[i]) <= 0x3c) || (uint8(rc[i]) >= 0x3f && uint8(rc[i]) <= 0x45) || uint8(rc[i]) == 0x54 || uint8(rc[i]) == 0x5a) {
          maybeNonPureOrNonStandalone = true;
        } else if (uint8(rc[i]) >= 0xa5 && uint8(rc[i]) <= 0xef) {
          maybeNonPureOrNonStandalone = false;
          maybeCode = false;
        } else if (uint8(rc[i]) == 0xf1 || uint8(rc[i]) == 0xf2 || uint8(rc[i]) == 0xf4 || uint8(rc[i]) == 0xfa) {
          maybeNonPureOrNonStandalone = true;
        } else if (uint8(rc[i]) >= 0xfb) {
          maybeNonPureOrNonStandalone = false;
          maybeCode = false;
        }
      } else {
        if (uint8(rc[i]) == 0x5b) {
          maybeCode = true;
        }
      }
    }
    return true;
  }

  function judge(ICorrectness correctness, IAnswer answer) external pure returns (bool) {
    uint gasLimit = correctness.gasLimit();
    return
      correctness.isOutput1Correct(answer.answer{ gas: gasLimit }(correctness.input1())) &&
      correctness.isOutput2Correct(answer.answer{ gas: gasLimit }(correctness.input2())) &&
      correctness.isOutput3Correct(answer.answer{ gas: gasLimit }(correctness.input3()));
  }
}
