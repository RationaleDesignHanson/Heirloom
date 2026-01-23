# Firestore Security Rules Rollback Procedure

## Emergency Contact

- **Firebase Project**: `heirloom-ios-prod`
- **Firebase Console**: https://console.firebase.google.com/project/heirloom-ios-prod
- **Project Owner**: Matt Hanson

## Pre-Deployment Checklist

Before deploying any security rule changes:

- [ ] Test rules thoroughly in Firebase emulator (`./scripts/test-firestore-rules.sh`)
- [ ] Verify all test scenarios pass
- [ ] Create backup of current rules (automatic backup location: `~/Desktop/firestore.rules.backup-YYYYMMDD`)
- [ ] Deploy to staging environment first (if available)
- [ ] Monitor for 24-48 hours in staging
- [ ] Document expected behavior changes
- [ ] Notify team of deployment window

## Deployment Process

### 1. Deploy Rules to Production

```bash
# Authenticate with Firebase (if not already)
firebase login

# Deploy rules
firebase deploy --only firestore:rules --project heirloom-ios-prod
```

### 2. Monitor Deployment

After deployment, monitor these metrics for 24 hours:

- **Firebase Console > Firestore > Rules**: Check for rule denial spikes
- **Firebase Console > Analytics**: Check for user drop-off
- **Crashlytics**: Monitor for new errors related to permissions
- **User Reports**: Watch for complaints about access issues

**Expected Metrics**:
- Rule denials should remain low (< 1% of requests)
- No significant change in active users
- No permission-related crashes

## Rollback Procedures

### EMERGENCY ROLLBACK (Within 5 Minutes)

If critical issues detected (users locked out, data inaccessible):

```bash
# 1. Restore from backup
cp ~/Desktop/firestore.rules.backup-YYYYMMDD /Users/matthanson/Heirloom/firestore.rules

# 2. Immediately redeploy old rules
firebase deploy --only firestore:rules --project heirloom-ios-prod

# 3. Verify rollback
# Check Firebase Console > Firestore > Rules to confirm old rules are active

# 4. Notify team and document issue
```

**Time to execute**: ~2-3 minutes

### PARTIAL ROLLBACK (Specific Rule Changes)

If only certain rules are problematic:

1. Open `firestore.rules` in editor
2. Revert specific rule blocks from backup
3. Test changes in emulator first
4. Deploy with `firebase deploy --only firestore:rules`

### INVESTIGATION MODE

If issues are unclear:

```bash
# Deploy rules with more permissive access temporarily
# Add temporary logging to understand access patterns
# Then re-deploy proper secured rules once understood
```

## Rollback Validation

After rolling back, verify:

- [ ] Users can access their data
- [ ] Share functionality works
- [ ] No permission denied errors in console
- [ ] App functions normally
- [ ] Firebase Console shows old rules active

## Common Issues and Solutions

### Issue: "Permission denied" errors

**Symptoms**: Users report they can't access their own data

**Solution**:
```bash
# Rollback immediately using emergency procedure above
```

### Issue: Rule denials spike but app works

**Symptoms**: Firebase Console shows many rule denials, but no user complaints

**Possible Cause**: Old app versions making deprecated queries

**Solution**:
- Investigate which queries are being denied
- May not require rollback if users are unaffected
- Plan gradual migration for old app versions

### Issue: Shares not working

**Symptoms**: Users can't create or access shares

**Solution**:
```bash
# Check specific share rules in firestore.rules
# Likely issue with allowedRecipients field or ownership checks
# Rollback share rules specifically
```

## Post-Rollback Actions

1. **Document the failure**: What went wrong? What was the impact?
2. **Root cause analysis**: Why did the rules fail?
3. **Test improvements**: Create better test scenarios
4. **Staged rollout**: Plan more gradual deployment next time
5. **Communication**: Update stakeholders and users

## Testing Before Next Deployment

Before attempting another deployment:

```bash
# 1. Start emulator
firebase emulators:start

# 2. Run comprehensive tests
./scripts/test-firestore-rules.sh

# 3. Manual testing in emulator UI
open http://localhost:4000

# 4. Test with actual app against emulator
# Update Heirloom app to point to localhost:8080 for testing

# 5. Verify all scenarios pass before production deployment
```

## Backup Locations

- **Local backups**: `~/Desktop/firestore.rules.backup-YYYYMMDD`
- **Git history**: `backup/pre-production-changes-YYYYMMDD` branch
- **Firebase Console**: Rules > Edit > Version history (90 days)

## Firebase Console Access

To manually rollback via console (if CLI unavailable):

1. Go to https://console.firebase.google.com/project/heirloom-ios-prod
2. Navigate to Firestore Database > Rules
3. Click "View version history"
4. Select previous working version
5. Click "Publish"

**Note**: This requires Firebase Console access with appropriate permissions.

## Monitoring Dashboards

After any rule changes, monitor:

- **Firebase Console > Firestore > Usage**: Request volume and patterns
- **Firebase Console > Firestore > Rules**: Denial rate and types
- **Crashlytics**: Permission-related crashes
- **Analytics**: User engagement and retention metrics

## Emergency Contact Escalation

If unable to resolve:

1. Check Firebase Status: https://status.firebase.google.com
2. Firebase Support: https://firebase.google.com/support
3. Stack Overflow: Tag questions with `firebase` and `firestore-security-rules`

---

**Last Updated**: 2026-01-23
**Document Owner**: Matt Hanson
**Review Frequency**: After each rule deployment
