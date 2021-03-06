LiveJournal.register_hook('init_settings', function ($) {
	$('.b-settings-apps-item-name').click(function () {
		$(this).parent().toggleClass('b-settings-apps-item-open');
	});
});

LiveJournal.register_hook('init_settings', function ($) {
	var Settings = {
		confirm_msg: LiveJournal.getLocalizedStr('.form.confirm', null, 'Save your changes?'),
		form_changed: false,
		navclickSave: function(e) {

			if ( Settings.form_changed && !Boolean(LJ.get('no_submit_window'))  && confirm(Settings.confirm_msg) ) {

				e.preventDefault();

				var redirectVal = $(e.target).attr('href');

				if ( redirectVal ) {
					Settings.$form.append('<input type="hidden" name="redirect_to" value="' + redirectVal + '">');
				}

				Settings.$form.submit();
			}
		}
	};

	window.Settings = Settings; //LJSUP-11806: we need to expose the object, because the current logic does not
								//allow to customize options on the specific pages without it.

	Settings.$form = $('#settings_form');
	if (!Settings.$form.length) {
		return;
	}
	// delegate onclick on all links to confirm form saving
	$(document).delegate('a', 'click', Settings.navclickSave);

	Settings.$form.delegate('select, input, textarea', 'change', function() {
		Settings.form_changed = true;
	});
});

LiveJournal.register_hook('init_settings', function ($) {
	var uIdInputName = 'LJ__Setting__Music_LJ__Setting__Music__Trava_trava_uid';

	var selectors = {
		Trava: '#LJ__Setting__Music__Trava_',
		LastFM: '#LJ__Setting__Music__LastFM_',
		connectLink: '.music-settings-connect',
		disconnectLink: '.music-settings-disconnect',
		userName: '.music-settings-username',
		musicSelect: 'select[name="LJ__Setting__Music_music_engine"]',
		uIdInput: 'input[name="' + uIdInputName + '"]'
	};

	var classNames = {
		login: 'music-settings-login',
		disconnect: 'music-settings-login-error',
		loading: 'music-settings-loading',
		error: 'music-settings-system-error'
	};

	var travaElement = $(selectors.Trava);

	//run code only on extensions page
	if (travaElement.length === 0) { return; }

	var musicSelect = $(selectors.musicSelect);
	var userName = travaElement.find(selectors.userName);
	var hiddenField = travaElement.find(selectors.uIdInput);

	var notLoginID = 1;
	var allClasses = [];
	var UID = hiddenField.val();
	var authForm = $('input[name="lj_form_auth"]').val();

	for (var name in classNames) {
		if (classNames.hasOwnProperty(name)) {
			allClasses.push(classNames[name]);
		}
	}

	classNames.allClasses = allClasses.join(' ');

	function onChangesMusic () {
		var currentID = '#' + $(this).val();
		var oldID = currentID == selectors.Trava ? selectors.LastFM : selectors.Trava;

		$(oldID).hide();
		$(currentID).show();
	}

	function saveChanges (data, success, error) {
		data.ajax = 1;
		data.lj_form_auth = authForm;

		$.ajax({
			type: 'POST',
			url: hiddenField.closest('form').attr('action'),
			data: data,
			success: success,
			error: error,
			dataType: 'text'
		});
	}

	musicSelect.bind('change', onChangesMusic);

	travaElement.trava({
			searchControl: false,
			uid: UID
		})
		.bind('travalogin', function (evt, data) {
			if (data) {
				hiddenField.val(data.uid);

				if (data.uid !== notLoginID) {
					var formData = {};
					formData[uIdInputName] = data.uid;

					saveChanges(formData, function () {
						travaElement.removeClass(classNames.allClasses).addClass(classNames.login).trava('getUserInfo');
					}, function () {
						travaElement.removeClass(classNames.allClasses).addClass(classNames.error);
					});
				} else {
					travaElement
						.removeClass(classNames.allClasses)
						.addClass(classNames.disconnect);
				}
			} else {
				travaElement
					.addClass(classNames.error)
					.removeClass(classNames.loading);
			}
		})
		.bind('travauserinfo', function (evt, data) {
			if (data && data.user) {
				userName.html(data.user.name || data.user.nickname);
			}
	});

	travaElement
		.delegate(selectors.connectLink, 'click', function (evt) {
			evt.preventDefault();

			travaElement
				.removeClass(classNames.allClasses)
				.addClass(classNames.loading)
				.trava('login');
		})
		.delegate(selectors.disconnectLink, 'click', function (evt) {
			evt.preventDefault();

			var formData = {};
			formData[uIdInputName] = 1;

			saveChanges(formData, function () {
				hiddenField.val(notLoginID);
				travaElement.removeClass(classNames.allClasses);
			}, function () {
				travaElement.removeClass(classNames.allClasses).addClass(classNames.connect);
			});
		});

	onChangesMusic.call(musicSelect[0]);

	if (Number(UID) !== notLoginID) {
		travaElement.trava('getUserInfo');
	}
});

LiveJournal.register_hook('page_load', function () {
	LiveJournal.run_hook('init_settings', jQuery);
});
