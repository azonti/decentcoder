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
    Publication
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

  uint public immutable announcementPhaseFinishedAt;
  uint public immutable submissionPhaseFinishedAt;
  uint public immutable publicationPhaseFinishedAt;
  uint public immutable peerreviewingPhaseFinishedAt;
  uint public immutable revisionPhaseFinishedAt;
  uint public immutable claimingPhaseFinishedAt;

  uint public constant timedrift = 10 minutes;

  bytes32 private immutable passphraseHash;

  bytes32 private immutable correctnessRCHash;

  uint public immutable participantMinimumDeposit;

  mapping(address => uint) public submissionTimestamp;

  mapping(address => bytes32) private answerRCHashAddressHash;

  ICorrectness public correctness;

  address[] private participants;

  uint[] private deposits;

  IAnswer[] private _answers; function answers() external view returns (IAnswer[] memory __answers) { __answers = _answers; }

  bool[][] private isAnswerCorrects;

  uint[] public isAnswerCorrectCount;

  mapping(address => uint) public index;

  uint public hash;

  uint public constant nReviewers = 3;

  address public winner;
  event WinnerChanged(address winner);

  constructor(
    address _organizer,
    uint _organizerDeposit,
    uint _announcementPhaseFinishedAt,
    uint _submissionPhaseFinishedAt,
    uint _publicationPhaseFinishedAt,
    uint _peerreviewingPhaseFinishedAt,
    uint _revisionPhaseFinishedAt,
    uint _claimingPhaseFinishedAt,
    bytes32 _passphraseHash,
    bytes32 _correctnessRCHash,
    uint _participantMinimumDeposit
  ) payable {
    require(_organizerDeposit <= msg.value, "IA");

    require(_announcementPhaseFinishedAt + timedrift <= _submissionPhaseFinishedAt, "IA");
    require(_submissionPhaseFinishedAt + timedrift <= _publicationPhaseFinishedAt, "IA");
    require(_publicationPhaseFinishedAt <= _peerreviewingPhaseFinishedAt, "IA");
    require(_peerreviewingPhaseFinishedAt <= _revisionPhaseFinishedAt, "IA");
    require(_revisionPhaseFinishedAt <= _claimingPhaseFinishedAt, "IA");

    phase = Phase.Announcement;
    emit PhaseChanged(Phase.Announcement);

    contestsManager = ContestsManager(msg.sender);

    createdBlockNumber = block.number;

    organizer = _organizer;

    organizerDeposit = _organizerDeposit;

    announcementPhaseFinishedAt = _announcementPhaseFinishedAt;
    submissionPhaseFinishedAt = _submissionPhaseFinishedAt;
    publicationPhaseFinishedAt = _publicationPhaseFinishedAt;
    peerreviewingPhaseFinishedAt = _peerreviewingPhaseFinishedAt;
    revisionPhaseFinishedAt = _revisionPhaseFinishedAt;
    claimingPhaseFinishedAt = _claimingPhaseFinishedAt;

    passphraseHash = _passphraseHash;

    correctnessRCHash = _correctnessRCHash;

    participantMinimumDeposit = _participantMinimumDeposit;

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

  function startPublicationPhase(
    ICorrectness _correctness
  )
  external
  onlyBy(organizer)
  onlyDuring(Phase.Submission)
  onlyAfter(submissionPhaseFinishedAt)
  onlyBefore(submissionPhaseFinishedAt + timedrift)
  {
    require(getRCHash(address(_correctness)) == correctnessRCHash, "IA");

    phase = Phase.Publication;
    emit PhaseChanged(Phase.Publication);

    correctness = _correctness;
  }

  function publish(
    IAnswer _answer
  )
  payable
  external
  onlyDuring(Phase.Publication)
  onlyBefore(publicationPhaseFinishedAt)
  {
    require(index[msg.sender] == 0, "NA");

    require(msg.value >= participantMinimumDeposit, "IV");

    require(keccak256(abi.encodePacked(getRCHash(address(_answer)), msg.sender)) == answerRCHashAddressHash[msg.sender], "IA");

    participants.push(msg.sender);

    deposits.push(msg.value);

    _answers.push(_answer);

    isAnswerCorrects.push();

    isAnswerCorrectCount.push();

    index[msg.sender] = participants.length;

    hash = uint(blockhash(block.number - 1)) % participants.length;
  }

  function punish(
    uint _0index,
    uint m
  )
  external
  onlyDuring(Phase.Publication)
  onlyAfter(publicationPhaseFinishedAt)
  onlyBefore(peerreviewingPhaseFinishedAt)
  {
    require(_answers[_0index] != IAnswer(0), "IA");

    require(!ContestsLibrary.isRCPureAndStandalone(address(_answers[_0index]), m), "IA");

    _answers[_0index] = IAnswer(0);

    msg.sender.transfer(deposits[_0index]);
    deposits[_0index] = 0;
  }

  function peerreview(
    bool[] memory isAnswerCorrect
  )
  external
  onlyDuring(Phase.Publication)
  onlyAfter(publicationPhaseFinishedAt)
  onlyBefore(peerreviewingPhaseFinishedAt)
  {
    uint _0index = index[msg.sender] - 1;
    require(isAnswerCorrects[_0index].length == 0, "NA");

    for (uint i = 0; i < nReviewers; i++) {
      isAnswerCorrects[_0index].push(isAnswerCorrect[i]);

      if (isAnswerCorrect[i]) {
        isAnswerCorrectCount[((_0index + hash) % participants.length + i) % participants.length]++;
      }
    }
  }

  function revise(
    uint _0index
  )
  external
  onlyDuring(Phase.Publication)
  onlyAfter(peerreviewingPhaseFinishedAt)
  onlyBefore(revisionPhaseFinishedAt)
  {
    require(_answers[_0index] != IAnswer(0), "IA");

    bool isParticipantAnswerCorrect;
    try ContestsLibrary.judge(correctness, _answers[_0index]) returns (bool _isParticipantAnswerCorrect) {
      isParticipantAnswerCorrect = _isParticipantAnswerCorrect;
    } catch {
      isParticipantAnswerCorrect = false;
    }

    if (isParticipantAnswerCorrect) {
      isAnswerCorrectCount[_0index] = type(uint).max;
    } else {
      isAnswerCorrectCount[_0index] = 0;
    }

    uint reward;
    for (uint i = 0; i < nReviewers; i++) {
      if (isParticipantAnswerCorrect != isAnswerCorrects[(participants.length + (participants.length + _0index - hash) % participants.length - i) % participants.length][i]) {
        reward += deposits[(participants.length + (participants.length + _0index - hash) % participants.length - i) % participants.length];
        deposits[(participants.length + (participants.length + _0index - hash) % participants.length - i) % participants.length] = 0;
      }
    }
    msg.sender.transfer(reward);
  }

  function claim()
  external
  onlyDuring(Phase.Publication)
  onlyAfter(revisionPhaseFinishedAt)
  onlyBefore(claimingPhaseFinishedAt)
  {
    require(submissionTimestamp[msg.sender] < submissionTimestamp[winner], "NA");

    uint _0index = index[msg.sender] - 1;
    require(_answers[_0index] != IAnswer(0), "NA");

    require(isAnswerCorrectCount[_0index] > nReviewers / 2, "WA");

    winner = msg.sender;
    emit WinnerChanged(msg.sender);
  }

  function terminateNormally()
  external
  onlyDuring(Phase.Publication)
  onlyAfter(claimingPhaseFinishedAt)
  {
    contestsManager.removeMe();

    payable(organizer).transfer(organizerDeposit);

    for (uint i = 0; i < participants.length; i++) {
      payable(participants[i]).transfer(deposits[i]);
    }

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
        phase == Phase.Publication &&
        block.timestamp <= peerreviewingPhaseFinishedAt &&
        !ContestsLibrary.isRCPureAndStandalone(address(correctness), m)
      )
    );

    contestsManager.removeMe();

    msg.sender.transfer(organizerDeposit);

    for (uint i = 0; i < participants.length; i++) {
      payable(participants[i]).transfer(deposits[i]);
    }

    selfdestruct(payable(winner));
  }

  receive() external payable {}
}
