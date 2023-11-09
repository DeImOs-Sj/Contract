// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HealthValidationDAO {
    address public owner;
    uint public stakeAmount = 1 ether;
    uint public rewardAmount = 0.1 ether;
    address[] public validatorAddresses; // Array to keep track of validator addresses

    enum ValidationStatus {
        Pending,
        Valid,
        Invalid
    }

    struct ProductValidation {
        address owner;
        string product;
        ValidationStatus status;
        uint validCount;
        uint invalidCount;
        mapping(address => bool) voted;
    }

    struct Validator {
        address payable addr;
        bool isActive;
        uint stakedAmount;
    }

    mapping(address => Validator) public validators;
    ProductValidation[] public validationRequests;
    uint public totalValidators;
    uint public totalStaked;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyValidator() {
        require(
            validators[msg.sender].isActive,
            "Only validators can perform this action"
        );
        _;
    }

    function addValidator() external payable {
        require(
            !validators[msg.sender].isActive,
            "You are already a validator"
        );
        require(msg.value == stakeAmount, "Must stake exactly 1 ether");

        validators[msg.sender] = Validator({
            addr: payable(msg.sender),
            isActive: true,
            stakedAmount: msg.value
        });

        totalStaked += msg.value;
        totalValidators++;
        validatorAddresses.push(msg.sender);
    }

    function submitValidationRequest(string memory _product) external {
        ProductValidation storage request = validationRequests.push();
        request.owner = msg.sender;
        request.product = _product;
        request.status = ValidationStatus.Pending;
    }

    function validateProduct(
        uint _requestIndex,
        bool _isValid
    ) external onlyValidator {
        ProductValidation storage request = validationRequests[_requestIndex];
        require(!request.voted[msg.sender], "Validator has already voted");
        require(
            request.status == ValidationStatus.Pending,
            "Validation is already finalized"
        );

        if (_isValid == true) {
            request.validCount++;
        } else {
            request.invalidCount++;
        }

        // request.voted[msg.sender] = true;
    }

    function finalizeValidation(uint _requestIndex) external {
        ProductValidation storage request = validationRequests[_requestIndex];
        require(
            request.status == ValidationStatus.Pending,
            "Validation is already finalized"
        );
        require(
            request.validCount + request.invalidCount == totalValidators,
            "Not all validators have voted"
        );

        if (request.validCount > request.invalidCount) {
            request.status = ValidationStatus.Valid;
        } else {
            request.status = ValidationStatus.Invalid;
        }

        distributeRewardsAndPenalties(request);
    }

    function distributeRewardsAndPenalties(
        ProductValidation storage request
    ) private {
        uint totalReward = totalStaked + (request.validCount * rewardAmount);
        uint rewardPerValidator = totalReward / totalValidators;

        for (uint i = 0; i < validatorAddresses.length; i++) {
            address validatorAddress = validatorAddresses[i];
            if (request.voted[validatorAddress]) {
                Validator storage validator = validators[validatorAddress];
                validator.addr.transfer(rewardPerValidator);
                totalStaked -= validator.stakedAmount;
            }
        }
    }

    function getValidVoteCount(
        uint _requestIndex
    ) external view returns (uint) {
        require(
            _requestIndex < validationRequests.length,
            "Invalid request index"
        );
        return validationRequests[_requestIndex].validCount;
    }

    function getInvalidVoteCount(
        uint _requestIndex
    ) external view returns (uint) {
        require(
            _requestIndex < validationRequests.length,
            "Invalid request index"
        );
        return validationRequests[_requestIndex].invalidCount;
    }

    function getFinalStatus(
        uint _requestIndex
    ) external view returns (ValidationStatus) {
        require(
            _requestIndex < validationRequests.length,
            "Invalid request index"
        );
        return validationRequests[_requestIndex].status;
    }

    function getDistributedRewards(
        address _validator
    ) external view returns (uint) {
        return validators[_validator].stakedAmount - totalStaked;
    }

    function getValidatorStake(
        address _validator
    ) external view returns (uint) {
        return validators[_validator].stakedAmount;
    }

    function contractBalance() external view returns (uint) {
        return address(this).balance;
    }
}
