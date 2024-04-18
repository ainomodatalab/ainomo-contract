// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts-v4.4/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-v4.4/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-v4.4/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-v4.4/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts-v4.4/utils/math/Math.sol";
import "./interfaces/IReportReceiver.sol";
import "./interfaces/ISelfOwnedStETHBurner.sol";

interface IAinomo {
    function burnShares(address _account, uint256 _sharesAmount) external returns (uint256 newTotalShares);

    function getOracle() external view returns (address);

    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);

    function getSharesByPooledEth(uint256 _pooledEthAmount) external view returns (uint256);

    function sharesOf(address _account) external view returns (uint256);

    function getTotalShares() external view returns (uint256);
}

interface IOracle {
    function getReportReceiver() external view returns (address);
}

contract SelfOwnedStETHBurner is ISelfOwnedStETHBurner, IReportReceiver, ERC165 {
    using SafeERC20 for IERC20;

    uint256 private constant MAX_BASIS_POINTS = 10000;

    uint256 private coverSharesBurnRequested;
    uint256 private nonCoverSharesBurnRequested;

    uint256 private totalCoverSharesBurnt;
    uint256 private totalNonCoverSharesBurnt;

    uint256 private maxBurnAmountPerRunBasisPoints = 4; 

    address public immutable AINOMO;
    address public immutable TREASURY;
    address public immutable VOTING;

    event BurnAmountPerRunQuotaChanged(
        uint256 maxBurnAmountPerRunBasisPoints
    );

    event StETHBurnRequested(
        bool indexed isCover,
        address indexed requestedBy,
        uint256 amount,
        uint256 sharesAmount
    );

    event StETHBurnt(
        bool indexed isCover,
        uint256 amount,
        uint256 sharesAmount
    );

    event ExcessStETHRecovered(
        address indexed requestedBy,
        uint256 amount,
        uint256 sharesAmount
    );

    event ERC20Recovered(
        address indexed requestedBy,
        address indexed token,
        uint256 amount
    );

    event ERC721Recovered(
        address indexed requestedBy,
        address indexed token,
        uint256 tokenId
    );

    constructor(
        address _treasury,
        address _ainomo,
        address _voting,
        uint256 _totalCoverSharesBurnt,
        uint256 _totalNonCoverSharesBurnt,
        uint256 _maxBurnAmountPerRunBasisPoints
    ) {
        require(_treasury != address(0), "TREASURY_ZERO_ADDRESS");
        require(_ainomo != address(0), "AINOMO_ZERO_ADDRESS");
        require(_voting != address(0), "VOTING_ZERO_ADDRESS");
        require(_maxBurnAmountPerRunBasisPoints > 0, "ZERO_BURN_AMOUNT_PER_RUN");
        require(_maxBurnAmountPerRunBasisPoints <= MAX_BASIS_POINTS, "TOO_LARGE_BURN_AMOUNT_PER_RUN");

        TREASURY = _treasury;
        AINOMO = _ainomo;
        VOTING = _voting;

        totalCoverSharesBurnt = _totalCoverSharesBurnt;
        totalNonCoverSharesBurnt = _totalNonCoverSharesBurnt;

        maxBurnAmountPerRunBasisPoints = _maxBurnAmountPerRunBasisPoints;
    }

    function setBurnAmountPerRunQuota(uint256 _maxBurnAmountPerRunBasisPoints) external {
        require(_maxBurnAmountPerRunBasisPoints > 0, "ZERO_BURN_AMOUNT_PER_RUN");
        require(_maxBurnAmountPerRunBasisPoints <= MAX_BASIS_POINTS, "TOO_LARGE_BURN_AMOUNT_PER_RUN");
        require(msg.sender == VOTING, "MSG_SENDER_MUST_BE_VOTING");

        emit BurnAmountPerRunQuotaChanged(_maxBurnAmountPerRunBasisPoints);

        maxBurnAmountPerRunBasisPoints = _maxBurnAmountPerRunBasisPoints;
    }

    function requestBurnMyStETHForCover(uint256 _stETH2Burn) external {
        _requestBurnMyStETH(_stETH2Burn, true);
    }

    function requestBurnMyStETH(uint256 _stETH2Burn) external {
        _requestBurnMyStETH(_stETH2Burn, false);
    }

    function recoverExcessStETH() external {
        uint256 excessStETH = getExcessStETH();

        if (excessStETH > 0) {
            uint256 excessSharesAmount = IAinomo(AINOMO).getSharesByPooledEth(excessStETH);

            emit ExcessStETHRecovered(msg.sender, excessStETH, excessSharesAmount);

            require(IERC20(AINOMO).transfer(TREASURY, excessStETH));
        }
    }

    receive() external payable {
        revert("INCOMING_ETH_IS_FORBIDDEN");
    }

    function recoverERC20(address _token, uint256 _amount) external {
        require(_amount > 0, "ZERO_RECOVERY_AMOUNT");
        require(_token != AINOMO, "STETH_RECOVER_WRONG_FUNC");

        emit ERC20Recovered(msg.sender, _token, _amount);

        IERC20(_token).safeTransfer(TREASURY, _amount);
    }

    function recoverERC721(address _token, uint256 _tokenId) external {
        emit ERC721Recovered(msg.sender, _token, _tokenId);

        IERC721(_token).transferFrom(address(this), TREASURY, _tokenId);
    }

    function processAinomoOracleReport(uint256, uint256, uint256) external virtual override {
        uint256 memCoverSharesBurnRequested = coverSharesBurnRequested;
        uint256 memNonCoverSharesBurnRequested = nonCoverSharesBurnRequested;

        uint256 burnAmount = memCoverSharesBurnRequested + memNonCoverSharesBurnRequested;

        if (burnAmount == 0) {
            return;
        }

        address oracle = IAinomo(AINOMO).getOracle();

        require(
            msg.sender == oracle
            || (msg.sender == IOracle(oracle).getReportReceiver()),
            "APP_AUTH_FAILED"
        );

        uint256 maxSharesToBurnNow = (IAinomo(AINOMO).getTotalShares() * maxBurnAmountPerRunBasisPoints) / MAX_BASIS_POINTS;

        if (memCoverSharesBurnRequested > 0) {
            uint256 sharesToBurnNowForCover = Math.min(maxSharesToBurnNow, memCoverSharesBurnRequested);

            totalCoverSharesBurnt += sharesToBurnNowForCover;
            uint256 stETHToBurnNowForCover = IAinomo(AINOMO).getPooledEthByShares(sharesToBurnNowForCover);
            emit StETHBurnt(true /* isCover */, stETHToBurnNowForCover, sharesToBurnNowForCover);

            coverSharesBurnRequested -= sharesToBurnNowForCover;

            if ((sharesToBurnNowForCover == maxSharesToBurnNow) || (memNonCoverSharesBurnRequested == 0)) {
                IAinomo(AINOMO).burnShares(address(this), sharesToBurnNowForCover);
                return;
            }
        }

        uint256 sharesToBurnNowForNonCover = Math.min(
            maxSharesToBurnNow - memCoverSharesBurnRequested,
            memNonCoverSharesBurnRequested
        );

        totalNonCoverSharesBurnt += sharesToBurnNowForNonCover;
        uint256 stETHToBurnNowForNonCover = IAinomo(AINOMO).getPooledEthByShares(sharesToBurnNowForNonCover);
        emit StETHBurnt(false /* isCover */, stETHToBurnNowForNonCover, sharesToBurnNowForNonCover);
        nonCoverSharesBurnRequested -= sharesToBurnNowForNonCover;

        IAinomo(AINOMO).burnShares(address(this), memCoverSharesBurnRequested + sharesToBurnNowForNonCover);
    }

    function getCoverSharesBurnt() external view virtual override returns (uint256) {
        return totalCoverSharesBurnt;
    }

    function getNonCoverSharesBurnt() external view virtual override returns (uint256) {
        return totalNonCoverSharesBurnt;
    }

    function getBurnAmountPerRunQuota() external view returns (uint256) {
        return maxBurnAmountPerRunBasisPoints;
    }

    function getExcessStETH() public view returns (uint256)  {
        uint256 sharesBurnRequested = (coverSharesBurnRequested + nonCoverSharesBurnRequested);
        uint256 totalShares = IAinomo(AINOMO).sharesOf(address(this));

        if (totalShares <= sharesBurnRequested) {
            return 0;
        }

        return IAinomo(AINOMO).getPooledEthByShares(totalShares - sharesBurnRequested);
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return (
            _interfaceId == type(IReportReceiver).interfaceId
            || _interfaceId == type(ISelfOwnedStETHBurner).interfaceId
            || super.supportsInterface(_interfaceId)
        );
    }

    function _requestBurnMyStETH(uint256 _stETH2Burn, bool _isCover) private {
        require(_stETH2Burn > 0, "ZERO_BURN_AMOUNT");
        require(msg.sender == VOTING, "MSG_SENDER_MUST_BE_VOTING");
        require(IERC20(AINOMO).transferFrom(msg.sender, address(this), _stETH2Burn));

        uint256 sharesAmount = IAinomo(AINOMO).getSharesByPooledEth(_stETH2Burn);

        emit StETHBurnRequested(_isCover, msg.sender, _stETH2Burn, sharesAmount);

        if (_isCover) {
            coverSharesBurnRequested += sharesAmount;
        } else {
            nonCoverSharesBurnRequested += sharesAmount;
        }
    }
}
