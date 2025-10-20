# Changelog

## 2024-08-13
- Restructured the finance domain schema around accounts, repayment schedules, and card utilisation reporting.

## 2024-08-14
- Converted all money columns to rupee-denominated decimals and updated helpers/forms to drop manual paise conversions.

## 2024-08-15
- Adopted precision 15, scale 2 decimals across the finance schema with human-readable column names and updated UI/forms.

## 2024-08-16
- Documented the production user journey covering setup, recurring workflows, exports, and safeguards for the decimal money release.
