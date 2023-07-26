// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./Guard.sol";

interface IBridge {
    // delayed transfer
    function setDelayPeriod(uint256 _period) external;

    function delayPeriod() external view returns (uint256);

    function setDelayThresholds(address[] calldata _tokens, uint256[] calldata _thresholds) external;

    function delayThresholds(address _token) external view returns (uint256);

    // volume control
    function setEpochLength(uint256 _length) external;

    function epochLength() external view returns (uint256);

    function setEpochVolumeCaps(address[] calldata _tokens, uint256[] calldata _caps) external;

    function epochVolumeCaps(address _token) external view returns (uint256);

    // pool bridge
    function setMinAdd(address[] calldata _tokens, uint256[] calldata _amounts) external;

    function minAdd(address _token) external view returns (uint256);

    function setMinSend(address[] calldata _tokens, uint256[] calldata _amounts) external;

    function minSend(address _token) external view returns (uint256);

    function setMaxSend(address[] calldata _tokens, uint256[] calldata _amounts) external;

    function maxSend(address _token) external view returns (uint256);

    function setNativeTokenTransferGas(uint256 _gasUsed) external;

    function setMinimalMaxSlippage(uint32 _minimalMaxSlippage) external;

    // peg bridge
    function setMinDeposit(address[] calldata _tokens, uint256[] calldata _amounts) external;

    function minDeposit(address _token) external view returns (uint256);

    function setMaxDeposit(address[] calldata _tokens, uint256[] calldata _amounts) external;

    function maxDeposit(address _token) external view returns (uint256);

    function setMinBurn(address[] calldata _tokens, uint256[] calldata _amounts) external;

    function minBurn(address _token) external view returns (uint256);

    function setMaxBurn(address[] calldata _tokens, uint256[] calldata _amounts) external;

    function maxBurn(address _token) external view returns (uint256);
}

abstract contract GuardedGovernor is Guard {
    uint64 public numGovernors;
    mapping(address => bool) public governors;

    event GovernorUpdated(address account, bool added);

    function _initGovernors(address[] memory _governors) internal {
        require(numGovernors == 0, "governors already initiated");
        for (uint256 i = 0; i < _governors.length; i++) {
            _addGovernor(_governors[i]);
        }
    }

    modifier onlyGovernor() {
        require(isGovernor(msg.sender), "Caller is not governor");
        _;
    }

    // delayed transfer

    function setDelayPeriod(address _target, uint256 _period) external onlyGovernor {
        if (!relaxed) {
            uint256 current = IBridge(_target).delayPeriod();
            require(_period > current, "not in relax mode, can only increase period");
        }
        IBridge(_target).setDelayPeriod(_period);
    }

    function setDelayThresholds(
        address _target,
        address[] calldata _tokens,
        uint256[] calldata _thresholds
    ) external onlyGovernor {
        if (!relaxed) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 current = IBridge(_target).delayThresholds(_tokens[i]);
                require(_thresholds[i] > current, "not in relax mode, can only increase threshold");
            }
        }
        IBridge(_target).setDelayThresholds(_tokens, _thresholds);
    }

    // volume control

    function setEpochLength(address _target, uint256 _length) external onlyGovernor {
        if (!relaxed) {
            uint256 current = IBridge(_target).epochLength();
            require(_length > current, "not in relax mode, can only increase length");
        }
        IBridge(_target).setEpochLength(_length);
    }

    function setEpochVolumeCaps(
        address _target,
        address[] calldata _tokens,
        uint256[] calldata _caps
    ) external onlyGovernor {
        if (!relaxed) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 current = IBridge(_target).epochVolumeCaps(_tokens[i]);
                require(_caps[i] < current, "not in relax mode, can only reduce cap");
            }
        }
        IBridge(_target).setEpochVolumeCaps(_tokens, _caps);
    }

    // pool bridge

    function setMinAdd(
        address _target,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyGovernor {
        if (!relaxed) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 current = IBridge(_target).minAdd(_tokens[i]);
                require(_amounts[i] > current, "not in relax mode, can only increase minAdd");
            }
        }
        IBridge(_target).setMinAdd(_tokens, _amounts);
    }

    function setMinSend(
        address _target,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyGovernor {
        if (!relaxed) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 current = IBridge(_target).minSend(_tokens[i]);
                require(_amounts[i] > current, "not in relax mode, can only increase minSend");
            }
        }
        IBridge(_target).setMinSend(_tokens, _amounts);
    }

    function setMaxSend(
        address _target,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyGovernor {
        if (!relaxed) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 current = IBridge(_target).maxSend(_tokens[i]);
                require(_amounts[i] < current, "not in relax mode, can only reduce maxSend");
            }
        }
        IBridge(_target).setMaxSend(_tokens, _amounts);
    }

    function setNativeTokenTransferGas(address _target, uint256 _gasUsed) external onlyGovernor {
        IBridge(_target).setNativeTokenTransferGas(_gasUsed);
    }

    function setMinimalMaxSlippage(address _target, uint32 _minimalMaxSlippage) external onlyGovernor {
        IBridge(_target).setMinimalMaxSlippage(_minimalMaxSlippage);
    }

    // peg bridge

    function setMinDeposit(
        address _target,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyGovernor {
        if (!relaxed) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 current = IBridge(_target).minDeposit(_tokens[i]);
                require(_amounts[i] > current, "not in relax mode, can only increase minDeposit");
            }
        }
        IBridge(_target).setMinDeposit(_tokens, _amounts);
    }

    function setMaxDeposit(
        address _target,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyGovernor {
        if (!relaxed) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 current = IBridge(_target).maxDeposit(_tokens[i]);
                require(_amounts[i] < current, "not in relax mode, can only reduce maxDeposit");
            }
        }
        IBridge(_target).setMaxDeposit(_tokens, _amounts);
    }

    function setMinBurn(
        address _target,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyGovernor {
        if (!relaxed) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 current = IBridge(_target).minBurn(_tokens[i]);
                require(_amounts[i] > current, "not in relax mode, can only increase minBurn");
            }
        }
        IBridge(_target).setMinBurn(_tokens, _amounts);
    }

    function setMaxBurn(
        address _target,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyGovernor {
        if (!relaxed) {
            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 current = IBridge(_target).maxBurn(_tokens[i]);
                require(_amounts[i] < current, "not in relax mode, can only reduce maxBurn");
            }
        }
        IBridge(_target).setMaxBurn(_tokens, _amounts);
    }

    function isGovernor(address _account) public view returns (bool) {
        return governors[_account];
    }

    function addGovernors(address[] calldata _accounts) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _addGovernor(_accounts[i]);
        }
    }

    function _addGovernor(address _account) internal {
        require(!isGovernor(_account), "Account is already governor");
        governors[_account] = true;
        numGovernors++;
        emit GovernorUpdated(_account, true);
    }

    function removeGovernors(address[] calldata _accounts) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _removeGovernor(_accounts[i]);
        }
    }

    function _removeGovernor(address _account) private {
        require(isGovernor(_account), "Account is not governor");
        governors[_account] = false;
        numGovernors--;
        emit GovernorUpdated(_account, false);
    }

    function renounceGovernor() external {
        _removeGovernor(msg.sender);
    }
}
