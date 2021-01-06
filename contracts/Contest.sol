// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./ContestsManager.sol";
import "./ContestsLibrary.sol";
import "./ICorrectness.sol";
import "./IAnswer.sol";

contract Contest {
  modifier onlyBy(address a) {
    require(msg.sender == a, "NA");
    _;
  }




  enum Phase {
    Announcement,
    Submission,
    Judgement
  }

  Phase public phase;
  event PhaseChanged(Phase phase);

  modifier onlyDuring(Phase p) {
    require(phase == p, "2EoL");
    _;
  }




  modifier onlyAfter(uint t) {
    require(block.timestamp > t, "2E");
    _;
  }

  modifier onlyBefore(uint t) {
    require(block.timestamp <= t, "2L");
    _;
  }




  function getRCHash(address a) internal view returns (bytes32) {
    bytes32 rcHash;
    assembly { rcHash := extcodehash(a) }
    return rcHash;
  }




  ContestsManager private immutable contestsManager;
  uint public immutable createdBlockNumber;
  address public immutable organizer;
  uint public immutable organizerDeposit;
  uint public immutable timedrift;
  uint public immutable announcementPhaseFinishedAt;
  uint public immutable submissionPhaseFinishedAt;
  uint public immutable prejudgementPhaseFinishedAt;
  uint public immutable judgementPhaseFinishedAt;
  uint public immutable claimingPhaseFinishedAt;
  bytes32 private immutable passphraseHash;
  bytes32 private immutable correctnessRCHash;

  mapping(address => uint) public submissionTimestamp;
  mapping(address => bytes32) private answerRCHashAddressHash;

  ICorrectness public correctness; // private

  mapping(address => bool) public isAnswerCorrect;

  address public winner;
  event WinnerChanged(address winner);

  constructor(
    address _organizer,
    uint _organizerDeposit,
    uint _timedrift,
    uint[] memory _phaseFinishedAts,
    bytes32 _passphraseHash,
    bytes32 _correctnessRCHash
  ) payable {
    require(_organizerDeposit <= msg.value, "IA");
    require(_phaseFinishedAts.length == 5, "IA");
    require(_phaseFinishedAts[1] >= _phaseFinishedAts[0] + _timedrift, "IA");
    require(_phaseFinishedAts[2] >= _phaseFinishedAts[1] + _timedrift, "IA");
    require(_phaseFinishedAts[3] >= _phaseFinishedAts[2], "IA");
    require(_phaseFinishedAts[4] >= _phaseFinishedAts[3], "IA");

    phase = Phase.Announcement;
    emit PhaseChanged(Phase.Announcement);

    contestsManager = ContestsManager(msg.sender);
    createdBlockNumber = block.number;
    organizer = _organizer;
    organizerDeposit = _organizerDeposit;
    timedrift = _timedrift;
    announcementPhaseFinishedAt = _phaseFinishedAts[0];
    submissionPhaseFinishedAt = _phaseFinishedAts[1];
    prejudgementPhaseFinishedAt = _phaseFinishedAts[2];
    judgementPhaseFinishedAt = _phaseFinishedAts[3];
    claimingPhaseFinishedAt = _phaseFinishedAts[4];
    passphraseHash = _passphraseHash;
    correctnessRCHash = _correctnessRCHash;

    submissionTimestamp[_organizer] = type(uint).max;

    winner = _organizer;
    emit WinnerChanged(_organizer);
  }

  function startSubmissionPhase(
    string memory passphrase
  )
  external
  onlyBy(organizer)
  onlyDuring(Phase.Announcement)
  onlyAfter(announcementPhaseFinishedAt)
  onlyBefore(announcementPhaseFinishedAt + timedrift)
  {
    require(keccak256(abi.encodePacked(passphrase)) == passphraseHash, "IA");

    phase = Phase.Submission;
    emit PhaseChanged(Phase.Submission);
  }

  function submit(
    bytes32 _answerRCHashAddressHash
  )
  external
  onlyDuring(Phase.Submission)
  onlyBefore(submissionPhaseFinishedAt)
  {
    require(msg.sender != organizer, "NA");

    submissionTimestamp[msg.sender] = block.timestamp;
    answerRCHashAddressHash[msg.sender] = _answerRCHashAddressHash;
  }

  function startJudgementPhase(
    ICorrectness _correctness
  )
  external
  onlyBy(organizer)
  onlyDuring(Phase.Submission)
  onlyAfter(submissionPhaseFinishedAt)
  onlyBefore(submissionPhaseFinishedAt + timedrift)
  {
    require(getRCHash(address(_correctness)) == correctnessRCHash, "IA");

    phase = Phase.Judgement;
    emit PhaseChanged(Phase.Judgement);

    correctness = _correctness;
  }

  function judge(
    IAnswer answer
  )
  external
  onlyDuring(Phase.Judgement)
  onlyAfter(prejudgementPhaseFinishedAt)
  onlyBefore(judgementPhaseFinishedAt)
  {
    require(keccak256(abi.encodePacked(getRCHash(address(answer)), msg.sender)) == answerRCHashAddressHash[msg.sender], "IA");
    require(ContestsLibrary.isRCPureAndStandalone2(address(answer)), "IA");
    require(ContestsLibrary.judge(correctness, answer), "WA");

    isAnswerCorrect[msg.sender] = true;
  }

  function claim()
  external
  onlyDuring(Phase.Judgement)
  onlyAfter(judgementPhaseFinishedAt)
  onlyBefore(claimingPhaseFinishedAt)
  {
    require(submissionTimestamp[msg.sender] < submissionTimestamp[winner], "NA");
    require(isAnswerCorrect[msg.sender], "NA");

    winner = msg.sender;
    emit WinnerChanged(msg.sender);
  }

  function terminateNormally()
  external
  onlyDuring(Phase.Judgement)
  onlyAfter(claimingPhaseFinishedAt)
  {
    contestsManager.removeMe();

    payable(organizer).transfer(organizerDeposit);

    selfdestruct(payable(winner));
  }

  function terminateAbnormally(uint m)
  external
  {
    require(
      (
        block.timestamp > announcementPhaseFinishedAt + timedrift &&
        phase == Phase.Announcement
      ) || (
        block.timestamp > submissionPhaseFinishedAt + timedrift &&
        phase == Phase.Submission
      ) || (
        phase == Phase.Judgement &&
        block.timestamp <= prejudgementPhaseFinishedAt &&
        !ContestsLibrary.isRCPureAndStandalone(address(correctness), m)
      )
    );

    contestsManager.removeMe();

    msg.sender.transfer(organizerDeposit);

    selfdestruct(payable(winner));
  }

  receive() external payable {}
}
